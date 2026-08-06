from __future__ import annotations

import hashlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from config.deployment.hosted_image import (
    BASE_IMAGE_NAME_DEFAULT,
    HOSTED_PORT_DEFAULT,
    HOSTED_STARTUP_COMMAND_DEFAULT,
    build_acr_build_args,
    build_hosted_image,
    build_source_image,
    parse_digest_from_build_output,
    prepare_hosted_image,
    render_hosted_dockerfile,
    resolve_pushed_digest,
    validate_digest,
)


BASE_DIGEST = "sha256:" + ("a" * 64)
HOSTED_DIGEST = "sha256:" + ("b" * 64)
BASE_IMAGE_REF = f"myregistry.azurecr.io/gpt-rag-orchestrator@{BASE_DIGEST}"
SOURCE_COMMIT = "eaa787340c27d8df5bb550147e95c5ecd02ad385"


class RenderHostedDockerfileTests(unittest.TestCase):
    def test_defaults_produce_hosted_entrypoint_cmd(self) -> None:
        content = render_hosted_dockerfile(BASE_IMAGE_REF)

        self.assertEqual(
            (
                f"FROM {BASE_IMAGE_REF}\n"
                f"EXPOSE {HOSTED_PORT_DEFAULT}\n"
                '''CMD ["uvicorn", "src.api.hosted_entrypoint:app", '''
                '''"--host", "0.0.0.0", "--port", "8088"]\n'''
            ),
            content,
        )
        self.assertIn(HOSTED_STARTUP_COMMAND_DEFAULT.split()[0], content)

    def test_custom_startup_command_and_port(self) -> None:
        content = render_hosted_dockerfile(
            BASE_IMAGE_REF,
            startup_command="python -m custom_entry --port 9000",
            port=9000,
        )

        self.assertIn("EXPOSE 9000\n", content)
        self.assertIn('"python", "-m", "custom_entry", "--port", "9000"', content)

    def test_rejects_mutable_tag_only_base_image(self) -> None:
        with self.assertRaises(ValueError):
            render_hosted_dockerfile("myregistry.azurecr.io/gpt-rag-orchestrator:v3.9.0")

    def test_rejects_empty_startup_command(self) -> None:
        with self.assertRaises(ValueError):
            render_hosted_dockerfile(BASE_IMAGE_REF, startup_command="   ")


class BuildAcrBuildArgsTests(unittest.TestCase):
    def test_builds_expected_argv_without_agent_pool(self) -> None:
        args = build_acr_build_args(
            registry="myregistry",
            image_name="gpt-rag-orchestrator",
            image_tag="v3.9.0-hosted",
            dockerfile_path="/tmp/x/Dockerfile",
            context_dir="/tmp/x",
        )

        self.assertEqual(
            [
                "az",
                "acr",
                "build",
                "--registry",
                "myregistry",
                "--image",
                "gpt-rag-orchestrator:v3.9.0-hosted",
                "--file",
                "/tmp/x/Dockerfile",
                "/tmp/x",
            ],
            args,
        )

    def test_appends_agent_pool_when_provided(self) -> None:
        args = build_acr_build_args(
            registry="myregistry",
            image_name="gpt-rag-orchestrator",
            image_tag="v3.9.0-hosted",
            dockerfile_path="/tmp/x/Dockerfile",
            context_dir="/tmp/x",
            agent_pool="build-pool",
        )

        self.assertEqual(args[-2:], ["--agent-pool", "build-pool"])

    def test_requires_registry_image_name_and_tag(self) -> None:
        base_kwargs = dict(
            registry="myregistry",
            image_name="gpt-rag-orchestrator",
            image_tag="v3.9.0-hosted",
            dockerfile_path="/tmp/x/Dockerfile",
            context_dir="/tmp/x",
        )
        for missing in ("registry", "image_name", "image_tag"):
            kwargs = dict(base_kwargs)
            kwargs[missing] = ""
            with self.assertRaises(ValueError):
                build_acr_build_args(**kwargs)


class ParseDigestFromBuildOutputTests(unittest.TestCase):
    def test_extracts_digest_when_present(self) -> None:
        output = f"Run ID: dt9 was successful ... digest: {BASE_DIGEST}\n"
        self.assertEqual(BASE_DIGEST, parse_digest_from_build_output(output))

    def test_returns_none_when_absent(self) -> None:
        self.assertIsNone(parse_digest_from_build_output("no digest here"))

    def test_validate_digest_rejects_mutable_or_malformed_values(self) -> None:
        self.assertEqual(BASE_DIGEST, validate_digest(f" {BASE_DIGEST} "))
        for value in ("v3.10.0", "sha256:abc", ""):
            with self.assertRaisesRegex(ValueError, "immutable OCI digest"):
                validate_digest(value)


class ResolvePushedDigestTests(unittest.TestCase):
    @patch("config.deployment.hosted_image.subprocess.run")
    def test_returns_digest_from_az_cli(self, mock_run: MagicMock) -> None:
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout=f"{BASE_DIGEST}\n", stderr=""
        )

        digest = resolve_pushed_digest(
            registry="myregistry",
            image_name="gpt-rag-orchestrator",
            image_tag="v3.9.0-hosted",
        )

        self.assertEqual(BASE_DIGEST, digest)
        mock_run.assert_called_once()
        called_args = mock_run.call_args.args[0]
        self.assertEqual(
            [
                "az",
                "acr",
                "repository",
                "show",
                "--name",
                "myregistry",
                "--image",
                "gpt-rag-orchestrator:v3.9.0-hosted",
                "--query",
                "digest",
                "-o",
                "tsv",
            ],
            called_args,
        )

    @patch("config.deployment.hosted_image.subprocess.run")
    def test_raises_on_unexpected_output(self, mock_run: MagicMock) -> None:
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="not-a-digest\n", stderr=""
        )

        with self.assertRaises(RuntimeError):
            resolve_pushed_digest(
                registry="myregistry",
                image_name="gpt-rag-orchestrator",
                image_tag="v3.9.0-hosted",
            )


class BuildHostedImageTests(unittest.TestCase):
    @patch("config.deployment.hosted_image.resolve_pushed_digest")
    @patch("config.deployment.hosted_image.subprocess.run")
    def test_builds_then_resolves_digest(
        self, mock_run: MagicMock, mock_resolve: MagicMock
    ) -> None:
        mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0)
        mock_resolve.return_value = BASE_DIGEST

        digest = build_hosted_image(
            registry="myregistry",
            base_image_ref=BASE_IMAGE_REF,
            image_name="gpt-rag-orchestrator",
            image_tag="v3.9.0-hosted",
            agent_pool="build-pool",
        )

        self.assertEqual(BASE_DIGEST, digest)
        mock_run.assert_called_once()
        build_args = mock_run.call_args.args[0]
        self.assertEqual(build_args[0:3], ["az", "acr", "build"])
        self.assertIn("--agent-pool", build_args)
        self.assertIn("build-pool", build_args)
        mock_resolve.assert_called_once_with(
            registry="myregistry",
            image_name="gpt-rag-orchestrator",
            image_tag="v3.9.0-hosted",
            azure_cli="az",
        )


class BuildSourceImageTests(unittest.TestCase):
    @patch("config.deployment.hosted_image.resolve_pushed_digest")
    @patch("config.deployment.hosted_image.subprocess.run")
    def test_public_basic_build_uses_standard_acr_task(
        self, mock_run: MagicMock, mock_resolve: MagicMock
    ) -> None:
        mock_resolve.return_value = BASE_DIGEST
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp)
            (source_dir / "Dockerfile").write_text("FROM scratch\n")

            digest = build_source_image(
                registry="myregistry",
                source_dir=source_dir,
                image_name=BASE_IMAGE_NAME_DEFAULT,
                image_tag="hosted-base-eaa787340c27",
            )

        self.assertEqual(BASE_DIGEST, digest)
        args = mock_run.call_args.args[0]
        self.assertEqual(["az", "acr", "build"], args[:3])
        self.assertNotIn("--agent-pool", args)


class PrepareHostedImageTests(unittest.TestCase):
    @patch("config.deployment.hosted_image.build_hosted_image")
    @patch("config.deployment.hosted_image.build_source_image")
    @patch("config.deployment.hosted_image.clone_pinned_source")
    def test_automatic_build_uses_manifest_pin_and_deterministic_tags(
        self,
        mock_clone: MagicMock,
        mock_build_source: MagicMock,
        mock_build_hosted: MagicMock,
    ) -> None:
        mock_build_source.return_value = BASE_DIGEST
        mock_build_hosted.return_value = HOSTED_DIGEST

        digest = prepare_hosted_image(
            image_version=None,
            registry="myregistry",
            registry_endpoint="myregistry.azurecr.io",
            image_name="gpt-rag-orchestrator",
            source_repo="https://github.com/azure/gpt-rag-orchestrator.git",
            source_ref="v3.10.0",
            source_commit=SOURCE_COMMIT,
        )

        self.assertEqual(HOSTED_DIGEST, digest)
        mock_clone.assert_called_once()
        self.assertEqual(
            "hosted-base-eaa787340c27",
            mock_build_source.call_args.kwargs["image_tag"],
        )
        self.assertIsNone(mock_build_source.call_args.kwargs["agent_pool"])
        self.assertEqual(
            "hosted-eaa787340c27-"
            + hashlib.sha256(
                HOSTED_STARTUP_COMMAND_DEFAULT.encode("utf-8")
            ).hexdigest()[:12],
            mock_build_hosted.call_args.kwargs["image_tag"],
        )
        self.assertEqual(
            (
                "myregistry.azurecr.io/"
                f"{BASE_IMAGE_NAME_DEFAULT}@{BASE_DIGEST}"
            ),
            mock_build_hosted.call_args.kwargs["base_image_ref"],
        )

    @patch("config.deployment.hosted_image.build_hosted_image")
    @patch("config.deployment.hosted_image.build_source_image")
    @patch("config.deployment.hosted_image.clone_pinned_source")
    @patch("config.deployment.hosted_image.validate_acr_agent_pool")
    def test_private_build_validates_and_uses_dedicated_agent_pool(
        self,
        mock_validate_pool: MagicMock,
        _mock_clone: MagicMock,
        mock_build_source: MagicMock,
        mock_build_hosted: MagicMock,
    ) -> None:
        mock_build_source.return_value = BASE_DIGEST
        mock_build_hosted.return_value = HOSTED_DIGEST

        prepare_hosted_image(
            image_version=None,
            registry="myregistry",
            registry_endpoint="myregistry.azurecr.io",
            image_name="gpt-rag-orchestrator",
            source_repo="https://github.com/azure/gpt-rag-orchestrator.git",
            source_ref="v3.10.0",
            source_commit=SOURCE_COMMIT,
            agent_pool="private-pool",
            resource_group="rg-test",
        )

        mock_validate_pool.assert_called_once_with(
            registry="myregistry",
            resource_group="rg-test",
            agent_pool="private-pool",
            azure_cli="az",
        )
        self.assertEqual(
            "private-pool",
            mock_build_source.call_args.kwargs["agent_pool"],
        )
        self.assertEqual(
            "private-pool",
            mock_build_hosted.call_args.kwargs["agent_pool"],
        )

    @patch("config.deployment.hosted_image.build_hosted_image")
    @patch("config.deployment.hosted_image.build_source_image")
    @patch("config.deployment.hosted_image.clone_pinned_source")
    def test_explicit_digest_override_skips_all_builds(
        self,
        mock_clone: MagicMock,
        mock_build_source: MagicMock,
        mock_build_hosted: MagicMock,
    ) -> None:
        digest = prepare_hosted_image(
            image_version=HOSTED_DIGEST,
            registry="",
            registry_endpoint="",
            image_name="gpt-rag-orchestrator",
            source_repo="",
            source_ref="",
            source_commit="",
        )

        self.assertEqual(HOSTED_DIGEST, digest)
        mock_clone.assert_not_called()
        mock_build_source.assert_not_called()
        mock_build_hosted.assert_not_called()

    def test_explicit_mutable_override_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "immutable OCI digest"):
            prepare_hosted_image(
                image_version="v3.10.0",
                registry="",
                registry_endpoint="",
                image_name="gpt-rag-orchestrator",
                source_repo="",
                source_ref="",
                source_commit="",
            )


if __name__ == "__main__":
    unittest.main()
