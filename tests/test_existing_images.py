from config.deployment.existing_images import (
    apply_existing_images,
    parse_container_app_images,
)


def test_parse_skips_placeholder_foreign_env_and_untagged():
    payload = [
        {"tags": {"azd-service-name": "frontend", "azd-env-name": "e1"},
         "image": "cr.azurecr.io/gpt-rag-ui:abc"},
        {"tags": {"azd-service-name": "dataingest", "azd-env-name": "e1"},
         "image": "mcr.microsoft.com/dotnet/samples:aspnetapp"},
        {"tags": {"azd-service-name": "orchestrator", "azd-env-name": "other"},
         "image": "cr.azurecr.io/orch:1"},
        {"tags": {}, "image": "cr.azurecr.io/x:1"},
        "garbage",
    ]
    assert parse_container_app_images(payload, "e1") == {
        "frontend": "cr.azurecr.io/gpt-rag-ui:abc"
    }
    assert parse_container_app_images({"not": "a list"}) == {}


def test_apply_sets_only_missing_images():
    apps = [
        {"service_name": "frontend"},
        {"service_name": "dataingest", "image": "explicit:1"},
        {"service_name": "orchestrator"},
    ]
    updated = apply_existing_images(
        apps, {"frontend": "ui:2", "dataingest": "ing:2"}
    )
    assert updated == ["frontend"]
    assert apps[0]["image"] == "ui:2"
    assert apps[1]["image"] == "explicit:1"
    assert "image" not in apps[2]
