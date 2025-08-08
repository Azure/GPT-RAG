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

# ---------- Zero Trust prompt ----------
if [ "${AZURE_ZERO_TRUST:-}" = "TRUE" ]; then
  read -r -p "Zero Trust enabled. Confirm resources are reachable (VM+Bastion)? [Y/n] " c
  if [ -n "$c" ] && [ "$c" != "Y" ] && [ "$c" != "y" ]; then
    exit 0
  fi
fi

# ---------- Docker preflight (hard stop with exact message) ----------
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running. Start Docker Desktop and try again"
  exit 11
fi

# ---------- Helpers ----------
find_repo_root() {
  local start="$1"
  local p
  if ! p="$(cd "$start" 2>/dev/null && pwd -P)"; then return 1; fi
  while :; do
    if [ "$(basename "$p")" = "gpt-rag" ] || [ -f "$p/infra/manifest.json" ]; then
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

manifest_path="$repo_root/infra/manifest.json"
[ -f "$manifest_path" ] || { red "manifest.json not found at $manifest_path"; exit 1; }
command -v jq >/dev/null 2>&1 || { red "jq is required to parse $manifest_path. Please install jq."; exit 1; }

base_dir="$(cd "$repo_root/.." && pwd -P)"
dot_azure="$repo_root/.azure"

# ---------- Global env & RG early check ----------
global_rg="$(get_azd_value "$repo_root" "AZURE_RESOURCE_GROUP")"
global_sub="$(get_azd_value "$repo_root" "AZURE_SUBSCRIPTION_ID")"

[ -n "$global_rg" ] || { red "AZURE_RESOURCE_GROUP not found in env."; exit 2; }
if ! rg_exists "$global_rg" "${global_sub:-}"; then
  if [ -n "${global_sub:-}" ]; then red "Resource group '$global_rg' in subscription '$global_sub'. not found."
  else red "Resource group '$global_rg'. not found."
  fi
  exit 3
fi

had_errors=0
release_default="$(jq -r '.release // empty' "$manifest_path")"

# ---------- Iterate components ----------
jq -c '.components[]' "$manifest_path" | while IFS= read -r comp; do
  name="$(printf "%s" "$comp" | jq -r '.name')"
  repo="$(printf "%s" "$comp" | jq -r '.repo')"
  c_tag="$(printf "%s" "$comp" | jq -r '.tag // empty')"
  c_branch="$(printf "%s" "$comp" | jq -r '.branch // empty')"

  # Desired ref (no implicit fallback)
  ref_type=""; ref=""
  if [ -n "$c_tag" ]; then
    if tag_exists "$repo" "$c_tag"; then ref_type="tag"; ref="$c_tag"
    else yellow "$name: tag '$c_tag' not found. Skipping."; continue
    fi
  elif [ -n "$release_default" ]; then
    if tag_exists "$repo" "$release_default"; then ref_type="tag"; ref="$release_default"
    else yellow "$name: tag '$release_default' not found. Skipping."; continue
    fi
  elif [ -n "$c_branch" ]; then
    if branch_exists "$repo" "$c_branch"; then ref_type="branch"; ref="$c_branch"
    else yellow "$name: branch '$c_branch' not found. Skipping."; continue
    fi
  else
    yellow "$name: neither tag nor branch specified. Skipping."
    continue
  fi

  target="$base_dir/$name"
  cyan "Deploying $name ($ref_type:$ref) -> $target"

  rm -rf "$target" 2>/dev/null || true

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
  fi
done

if [ "$had_errors" -ne 0 ]; then
  red "One or more components failed. See logs above."
  exit 1
fi

green "All components processed."
