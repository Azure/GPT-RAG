#!/usr/bin/env bash
# Cross-platform bash (Linux/macOS) parent deployer for gpt-rag
# Runs child scripts/deploy.sh in each component directory.

set -uo pipefail
IFS=$'\n\t'

# ---------- Colors ----------
cyan()   { printf "\033[36m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }

# ---------- Helpers ----------
find_repo_root() {
  local start="$1"
  local p
  if ! p="$(cd "$start" 2>/dev/null && pwd -P)"; then return 1; fi
  while :; do
    if [ "$(basename "$p")" = "gpt-rag" ] || [ -f "$p/manifest.json" ]; then
      printf "%s" "$p"; return 0
    fi
    local parent; parent="$(dirname "$p")"
    [ "$parent" = "$p" ] && break
    p="$parent"
  done
  return 1
}

tag_exists()    { [ -n "$(git ls-remote --tags  "$1" "$2" 2>/dev/null || true)" ]; }
branch_exists() { [ -n "$(git ls-remote --heads "$1" "$2" 2>/dev/null || true)" ]; }

get_azd_value() {
  local repo_root="$1" key="$2" val=""
  if command -v azd >/dev/null 2>&1; then
    if pushd "$repo_root" >/dev/null 2>&1; then
      local lines
      if lines="$(azd env get-values 2>/dev/null)"; then
        val="$(printf "%s\n" "$lines" | tr -d '\r' | awk -F= -v k="$key" '
          $1==k { sub(/^[ \t"]+/, "", $2); sub(/[ \t"]+$/, "", $2); gsub(/^"/,"",$2); gsub(/"$/,"",$2); print $2; exit }')"
      fi
      popd >/dev/null 2>&1 || true
    fi
  fi
  if [ -z "$val" ]; then
    local env_dir
    env_dir="$(find "$repo_root/.azure" -type d -maxdepth 1 -mindepth 1 2>/dev/null | head -n1 || true)"
    if [ -n "$env_dir" ] && [ -f "$env_dir/.env" ]; then
      val="$(tr -d '\r' < "$env_dir/.env" | awk -F= -v k="$key" '
        $1==k { sub(/^[ \t"]+/, "", $2); sub(/[ \t"]+$/, "", $2); gsub(/^"/,"",$2); gsub(/"$/,"",$2); print $2; exit }')"
    fi
  fi
  printf "%s" "$val"
}

rg_exists() {
  if ! command -v az >/dev/null 2>&1; then
    red "Azure CLI (az) not found; cannot verify resource group '$1'."
    return 1
  fi
  local args=(group exists -n "$1")
  [ -n "${2:-}" ] && args+=("--subscription" "$2")
  local res; res="$(az "${args[@]}" 2>/dev/null)" || return 1
  [ "$(printf "%s" "$res" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" = "true" ]
}

copy_dot_azure() {
  [ -d "$1" ] || return 0
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$1/" "$2/.azure/" >/dev/null 2>&1 || cp -R "$1" "$2"/ >/dev/null 2>&1
  else
    cp -R "$1" "$2"/ >/dev/null 2>&1 || true
  fi
}

# ---------- Locate repo root ----------
start_dir="${BASH_SOURCE[0]:-}"
if [ -n "$start_dir" ] && [ -f "$start_dir" ]; then
  start_dir="$(cd "$(dirname "$start_dir")" && pwd -P)"
else
  start_dir="$(pwd -P)"
fi

repo_root="$(find_repo_root "$start_dir")" || { red "Run this from inside a gpt-rag repo."; exit 1; }
command -v git >/dev/null 2>&1 || { red "Git not found in PATH."; exit 1; }
export PYTHONPATH="$repo_root${PYTHONPATH:+:$PYTHONPATH}"

manifest_path="$repo_root/manifest.json"
[ -f "$manifest_path" ] || { red "manifest.json not found at $manifest_path"; exit 1; }
command -v jq >/dev/null 2>&1 || { red "jq is required to parse $manifest_path. Please install jq."; exit 1; }

base_dir="$(cd "$repo_root/.." && pwd -P)"
dot_azure="$repo_root/.azure"

# Mirror the materialized azd environment before invoking shared Python
# publishers. In particular, the final hosted cutover requires App
# Configuration, resource-group, resource-token, and deploy-handoff values
# that are not inherited by a clean shell merely because get_azd_value reads
# them into local variables below.
while IFS='=' read -r key value; do
  [[ -z "$key" ]] && continue
  value="${value%\"}"
  value="${value#\"}"
  export "$key=$value"
done < <(cd "$repo_root" && azd env get-values)

# ---------- Global env & RG early check ----------
global_rg="$(get_azd_value "$repo_root" "AZURE_RESOURCE_GROUP")"
global_sub="$(get_azd_value "$repo_root" "AZURE_SUBSCRIPTION_ID")"
network_isolation="$(get_azd_value "$repo_root" "NETWORK_ISOLATION" | tr '[:upper:]' '[:lower:]')"
acr_task_agent_pool="$(get_azd_value "$repo_root" "ACR_TASK_AGENT_POOL")"
# ADR-0001 rev. 5: read back the deployment topology that scripts/preProvision
# already resolved and materialized into the azd environment. preDeploy must
# never re-derive the fresh/existing/sticky decision independently --
# config.deployment.topology --describe performs no Azure CLI lookups; it is a
# pure read-back of DEPLOYMENT_TOPOLOGY / the legacy flag pair, so this always
# agrees with preProvision and postProvision.
deployment_topology_value="$(get_azd_value "$repo_root" "DEPLOYMENT_TOPOLOGY")"
deploy_hosted_value="$(get_azd_value "$repo_root" "DEPLOY_HOSTED_AGENT_ORCHESTRATION")"
deploy_panel_value="$(get_azd_value "$repo_root" "DEPLOY_ADMINISTRATIVE_PANEL")"
[ -n "$deployment_topology_value" ] && export DEPLOYMENT_TOPOLOGY="$deployment_topology_value"
[ -n "$deploy_hosted_value" ] && export DEPLOY_HOSTED_AGENT_ORCHESTRATION="$deploy_hosted_value"
[ -n "$deploy_panel_value" ] && export DEPLOY_ADMINISTRATIVE_PANEL="$deploy_panel_value"

command -v python3 >/dev/null 2>&1 || { red "python3 is required to resolve the GPT-RAG deployment topology."; exit 1; }
topology_json="$(cd "$repo_root" && python3 -m config.deployment.topology --describe)" || {
  red "Failed to resolve the GPT-RAG deployment topology. Ensure scripts/preProvision ran successfully before azd deploy."
  exit 1
}
hosted_mode="$(printf "%s" "$topology_json" | jq -er '.deploy_hosted_agent_orchestration | if type == "boolean" then tostring else error("invalid hosted mode") end')" &&
administrative_panel="$(printf "%s" "$topology_json" | jq -er '.deploy_administrative_panel | if type == "boolean" then tostring else error("invalid panel mode") end')" &&
deployment_mode="$(printf "%s" "$topology_json" | jq -er '.topology | select(. == "classic" or . == "hosted-no-panel")')" &&
selected_components="$(printf "%s" "$topology_json" | jq -er '.components | if type == "array" and length > 0 then join(" ") else error("invalid component selection") end')" || {
  red "Resolved topology JSON is incomplete or invalid; refusing to select a deployment path."
  exit 1
}
cyan "GPT-RAG deployment mode: $deployment_mode"

if [ "$network_isolation" = "true" ] && [ "$(printf "%s" "${RUN_FROM_JUMPBOX:-}" | tr '[:upper:]' '[:lower:]')" != "true" ]; then
  red "NETWORK_ISOLATION=true deployments must run from the jumpbox/VNet. Provision from the workstation, then run azd deploy from the jumpbox with RUN_FROM_JUMPBOX=true."
  exit 4
fi

if ! docker info >/dev/null 2>&1; then
  if [ "$network_isolation" = "true" ] || [ -n "$acr_task_agent_pool" ]; then
    yellow "Docker is not available; component deploys will use ACR remote builds."
  else
    yellow "Docker daemon is not running; component deploy scripts will fall back to ACR remote builds where supported."
  fi
fi

[ -n "$global_rg" ] || { red "AZURE_RESOURCE_GROUP not found in env."; exit 2; }
if ! rg_exists "$global_rg" "${global_sub:-}"; then
  if [ -n "${global_sub:-}" ]; then red "Resource group '$global_rg' in subscription '$global_sub'. not found."
  else red "Resource group '$global_rg'. not found."
  fi
  exit 3
fi

had_errors=0
release_default="$(jq -r '.release // empty' "$manifest_path")"

if [[ "$hosted_mode" =~ ^(1|true|t|yes|y)$ ]]; then
  hosted_project="$repo_root/hosted-agent"
  hosted_scope="$(get_azd_value "$repo_root" "HOSTED_AGENT_RESOURCE_SCOPE")"
  project_endpoint="$(get_azd_value "$repo_root" "AZURE_AI_PROJECT_ENDPOINT")"
  project_resource_id="$(get_azd_value "$repo_root" "AZURE_AI_PROJECT_RESOURCE_ID")"
  environment_name="$(get_azd_value "$repo_root" "AZURE_ENV_NAME")"
  hosted_startup_command="$(get_azd_value "$repo_root" "HOSTED_AGENT_STARTUP_COMMAND")"
  hosted_prepared="$(get_azd_value "$repo_root" "HOSTED_AGENT_PREPARED" | tr '[:upper:]' '[:lower:]')"
  deploy_hosted="$(get_azd_value "$repo_root" "DEPLOY_HOSTED_AGENT" | tr '[:upper:]' '[:lower:]')"
  hosted_agent_digest="$(get_azd_value "$repo_root" "HOSTED_AGENT_IMAGE_VERSION")"

  [ -f "$hosted_project/azure.yaml" ] || { red "Hosted agent azd project not found at $hosted_project."; exit 1; }
  if [ "$hosted_prepared" != "true" ] || [ "$deploy_hosted" != "true" ]; then
    red "Hosted prerequisites are prepared, but the immutable deploy handoff is not materialized."
    red "Run: scripts/prepareHostedDeployment.sh && azd provision && azd deploy"
    exit 1
  fi
  export HOSTED_AGENT_RESOURCE_SCOPE="$hosted_scope"
  export AZURE_AI_PROJECT_ENDPOINT="$project_endpoint"
  export AZURE_AI_PROJECT_RESOURCE_ID="$project_resource_id"
  export HOSTED_AGENT_STARTUP_COMMAND="$hosted_startup_command"
  export HOSTED_AGENT_PREPARED="$hosted_prepared"
  export DEPLOY_HOSTED_AGENT="$deploy_hosted"
  export HOSTED_AGENT_IMAGE_VERSION="$hosted_agent_digest"
  (cd "$repo_root" && python3 -m config.deployment.topology --validate-hosted-deploy >/dev/null) || {
    red "Hosted deployment prerequisites or immutable image digest are invalid."
    exit 1
  }
  green "Hosted-agent deploy handoff ready: $hosted_agent_digest"

  copy_dot_azure "$dot_azure" "$hosted_project"
  (
    cd "$hosted_project"
    azd env set HOSTED_AGENT_IMAGE_VERSION "$hosted_agent_digest" --environment "$environment_name" --no-prompt >/dev/null || exit 1
    azd env set FOUNDRY_PROJECT_ENDPOINT "$project_endpoint" --environment "$environment_name" --no-prompt >/dev/null || exit 1
    azd env set AZURE_AI_PROJECT_ID "$project_resource_id" --environment "$environment_name" --no-prompt >/dev/null || exit 1
    azd deploy orchestrator-agent --environment "$environment_name" --no-prompt
  ) || { red "Hosted orchestrator deployment failed."; exit 1; }
  (
    cd "$hosted_project"
    azd ai agent invoke --protocol invocations --new-session --timeout 180 --environment "$environment_name" --no-prompt "Reply with exactly: GPT-RAG hosted smoke OK." >/dev/null
  ) || { red "Hosted orchestrator smoke request failed; the classic chat path remains active."; exit 1; }

  invocations_endpoint="$(get_azd_value "$hosted_project" "AGENT_ORCHESTRATOR_AGENT_INVOCATIONS_ENDPOINT")"
  [ -n "$invocations_endpoint" ] || { red "Hosted deployment did not publish AGENT_ORCHESTRATOR_AGENT_INVOCATIONS_ENDPOINT."; exit 1; }
  hosted_base_url="$(
    cd "$repo_root"
    python3 -m config.deployment.hosted --invocations-endpoint "$invocations_endpoint"
  )" || { red "Hosted Invocations endpoint is not compatible with the UI endpoint contract."; exit 1; }

  export HOSTED_AGENT_BASE_URL="$hosted_base_url"
  export HOSTED_AGENT_RESOURCE_SCOPE="$hosted_scope"

  continuity_venv="$(mktemp -d)"
  if ! (
    python3 -m venv "$continuity_venv" &&
    "$continuity_venv/bin/python" -m pip install --quiet --disable-pip-version-check -r "$repo_root/config/requirements.txt" &&
    cd "$repo_root" &&
    "$continuity_venv/bin/python" -m config.continuity.setup --activate
  ); then
    rm -rf "$continuity_venv"
    red "Hosted continuity activation failed closed."
    exit 1
  fi
  rm -rf "$continuity_venv"
fi

# ---------- Iterate components ----------
while IFS= read -r comp; do
  name="$(printf "%s" "$comp" | jq -r '.name')"
  if [[ " $selected_components " != *" $name "* ]]; then
    yellow "$name is not deployed in $deployment_mode mode."
    continue
  fi
  repo="$(printf "%s" "$comp" | jq -r '.repo')"
  c_tag="$(printf "%s" "$comp" | jq -r '.tag // empty')"
  c_branch="$(printf "%s" "$comp" | jq -r '.branch // empty')"
  expected_commit="$(printf "%s" "$comp" | jq -r '.commit // empty')"

  # Desired ref (no implicit fallback)
  ref_type=""; ref=""
  if [ -n "$c_tag" ]; then
    if tag_exists "$repo" "$c_tag"; then ref_type="tag"; ref="$c_tag"
    else
      yellow "$name: tag '$c_tag' not found. Skipping."
      [ "$hosted_mode" = "true" ] && had_errors=1
      continue
    fi
  elif [ -n "$release_default" ]; then
    if tag_exists "$repo" "$release_default"; then ref_type="tag"; ref="$release_default"
    else
      yellow "$name: tag '$release_default' not found. Skipping."
      [ "$hosted_mode" = "true" ] && had_errors=1
      continue
    fi
  elif [ -n "$c_branch" ]; then
    if branch_exists "$repo" "$c_branch"; then ref_type="branch"; ref="$c_branch"
    else
      yellow "$name: branch '$c_branch' not found. Skipping."
      [ "$hosted_mode" = "true" ] && had_errors=1
      continue
    fi
  else
    yellow "$name: neither tag nor branch specified. Skipping."
    [ "$hosted_mode" = "true" ] && had_errors=1
    continue
  fi

  target="$base_dir/$name"
  cyan "Deploying $name ($ref_type:$ref) -> $target"

  if [ -d "$target" ]; then
    yellow "  ℹ️  '$name' already exists at $target, verifying pin."
  else
    if [ "$ref_type" = "branch" ]; then
      if ! git clone --depth 1 --branch "$ref" --quiet "$repo" "$target" >/dev/null 2>&1; then
        red "$name: git clone failed."; had_errors=1; continue
      fi
    else
      if ! git clone --depth 1 --quiet "$repo" "$target" >/dev/null 2>&1; then
        red "$name: git clone failed."; had_errors=1; continue
      fi
      if ! git -C "$target" fetch --tags --force --depth 1 --quiet origin "$ref" >/dev/null 2>&1; then
        red "$name: git fetch tag failed."; had_errors=1; continue
      fi
      if ! git -C "$target" -c advice.detachedHead=false checkout -q -f "$ref" >/dev/null 2>&1; then
        red "$name: git checkout tag failed."; had_errors=1; continue
      fi
    fi
  fi

  if [ -n "$expected_commit" ]; then
    actual_commit="$(git -C "$target" rev-parse HEAD 2>/dev/null || true)"
    if [ "$actual_commit" != "$expected_commit" ]; then
      red "$name must resolve to $expected_commit but $target is at $actual_commit. Remove or relocate the stale sibling checkout."
      had_errors=1
      continue
    fi
  fi

  git config --global --add safe.directory "$target" >/dev/null 2>&1 || true
  copy_dot_azure "$dot_azure" "$target"

  deploy_sh="$target/scripts/deploy.sh"
  if [ -f "$deploy_sh" ]; then
    log_dir="$target/.logs"; mkdir -p "$log_dir"
    ts="$(date +%Y%m%d_%H%M%S)"
    log="$log_dir/deploy_${ts}.log"

    echo "Running child deploy in $target: scripts/deploy.sh -> $(basename "$log")"
    (
      cd "$target" && bash "scripts/deploy.sh"
    ) >"$log" 2>&1
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
      red "$name: deploy script failed with exit code $exit_code. See log: $log"
      had_errors=1
    else
      green "$name: deploy script finished. Log: $log"
    fi
  else
    echo "$name: no scripts/deploy.sh found, skipping child deploy."
    [ "$hosted_mode" = "true" ] && had_errors=1
  fi
done < <(jq -c '.components[]' "$manifest_path")

if [ "$had_errors" -ne 0 ]; then
  red "One or more components failed. See logs above."
  exit 1
fi

if [[ "$hosted_mode" =~ ^(1|true|t|yes|y)$ ]]; then
  export HOSTED_CUTOVER_COMPLETE=true
  migrating_classic_runtime=false
  [[ "$(printf "%s" "${PRESERVE_CLASSIC_RUNTIME:-}" | tr '[:upper:]' '[:lower:]')" = "true" ]] && migrating_classic_runtime=true
  (
    cd "$repo_root"
    python3 -m config.deployment.appconfig --require-hosted-endpoint
  ) || { red "Failed to publish the hosted-agent endpoint contract."; exit 1; }
  if ! azd env set HOSTED_AGENT_BASE_URL "$hosted_base_url" --environment "$environment_name" --no-prompt >/dev/null; then
    if [ "$migrating_classic_runtime" = "true" ]; then
      export HOSTED_CUTOVER_COMPLETE=false
      (cd "$repo_root" && python3 -m config.deployment.appconfig >/dev/null) || {
        red "Hosted endpoint persistence and classic-selector compensation both failed."
        exit 1
      }
    fi
    red "Hosted cutover endpoint could not be persisted."
    exit 1
  fi
  azd env set HOSTED_CUTOVER_COMPLETE true --environment "$environment_name" --no-prompt >/dev/null || {
    if [ "$migrating_classic_runtime" = "true" ]; then
      export HOSTED_CUTOVER_COMPLETE=false
      (cd "$repo_root" && python3 -m config.deployment.appconfig >/dev/null) || {
        red "Hosted marker persistence and classic-selector compensation both failed."
        exit 1
      }
    fi
    red "Hosted cutover success marker could not be persisted."
    exit 1
  }
fi

green "All components processed."
