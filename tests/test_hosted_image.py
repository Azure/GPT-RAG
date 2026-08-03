from __future__ import annotations

import subprocess
import unittest
from unittest.mock import MagicMock, patch

from config.deployment.hosted_image import (
    HOSTED_PORT_DEFAULT,
    HOSTED_STARTUP_COMMAND_DEFAULT,
    build_acr_build_args,
    build_hosted_image,
    parse_digest_from_build_output,
    render_hosted_dockerfile,
    resolve_pushed_digest,
)


BASE_DIGEST = "sha256:" + ("a" * 64)
BASE_IMAGE_REF = f"myregistry.azurecr.io/gpt-rag-orchestrator@{BASE_DIGEST}"


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
        )


if __name__ == "__main__":
    unittest.main()
