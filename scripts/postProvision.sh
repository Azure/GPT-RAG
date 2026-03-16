#!/usr/bin/env bash
set -euo pipefail

# Ensure the temporary venv is always cleaned up, even on early exits.
# Cleanup failures must never cause the post-provision hook to report failure.
cleanup() {
  deactivate 2>/dev/null || true
  rm -rf config/.venv_temp 2>/dev/null || true
}
trap cleanup EXIT

echo "🔧 Running post-provision steps..."
echo

#-------------------------------------------------------------------------------
# Mirror azd environment variables into process environment
# This avoids persisting secrets in the User environment (registry)
#-------------------------------------------------------------------------------

while IFS='=' read -r key value; do
  # Skip empty keys or lines without '='
  [[ -z "$key" ]] && continue

  # Trim surrounding double quotes from the value (if present)
  value="${value%\"}"
  value="${value#\"}"

  # Export into current shell
  export "$key=$value"
done < <(azd env get-values)

#-------------------------------------------------------------------------------
# Zero Trust Information
#-------------------------------------------------------------------------------
echo
if [[ "$(echo "${NETWORK_ISOLATION:-false}" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
  echo "🔒 Zero Trust enabled."
  echo "🚧 NOTE: If app config failed, run the azd provision again - this is due to token timeout restrictions."
  echo "Access to Azure resources is restricted to the VNet."
  echo "Ensure you run scripts/postProvision.sh from within the VNet."
  echo "If you are using a local machine, make sure you have a VPN connection to the VNet."
  echo "You can also use the Test VM to access the environment and complete the setup."
  read -p "Are you running this script from inside the VNet or via VPN? [Y/n]: " answer
  if [[ ! "$(echo "${answer:-y}" | tr '[:upper:]' '[:lower:]')" =~ ^(y|yes)$ ]]; then
    echo "❌ Please run this script from inside the VNet or with VPN access. Exiting."
    exit 0
  fi
else
  echo "🚧 Provisioning basic architecture."
fi

#-------------------------------------------------------------------------------
# Container APP API Keys Warning
#-------------------------------------------------------------------------------
echo
if [[ "$(echo "${USE_CAPP_API_KEY:-false}" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
  echo "🔑 Using API Key for Container Apps access."
  echo "⚠️ IMPORTANT: Each App API Key was initialized with resourceToken."
  echo "    Please update to a custom API key ASAP."
fi

###############################################################################
# Zero Trust Information
###############################################################################
echo
if [[ "$(echo "${NETWORK_ISOLATION:-false}" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
  echo "🔒 Zero Trust enabled."
  echo "🚧 NOTE: If app config failed, run the azd provision again - this is due to token timeout restrictions."
  echo "Access to Azure resources is restricted to the VNet."
  echo "Ensure you run scripts/postProvision.sh from within the VNet."
  echo "If you’re using a local machine, make sure you have a VPN connection to the VNet."
  echo "You can also use the Test VM to access the environment and complete the setup."
  read -p "Are you running this script from inside the VNet or via VPN? [Y/n]: " answer
  if [[ ! "$(echo "${answer:-n}" | tr '[:upper:]' '[:lower:]')" =~ ^y ]]; then
    echo "❌ Please run this script from inside the VNet or with VPN access. Exiting."
    exit 0
  fi
else
  echo "🚧 Provisioning basic architecture."
fi

###############################################################################
# Check required environment variable
###############################################################################
echo "📋 Current environment variables:"
for v in APP_CONFIG_ENDPOINT ; do
  printf "  %s=%s\n" "$v" "${!v:-<unset>}"
done

if [[ -z "${APP_CONFIG_ENDPOINT:-}" ]]; then
  echo "❗️ APP_CONFIG_ENDPOINT environment variable must be set before running this script."
  exit 1
fi

###############################################################################
# Setup Python environment
###############################################################################
echo "📦 Creating temporary venv…"
python3 -m venv --without-pip config/.venv_temp
source config/.venv_temp/bin/activate
echo "⬇️ Manually bootstrapping pip…"
curl -sS https://bootstrap.pypa.io/get-pip.py | python

echo "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r config/requirements.txt

###############################################################################
# 1) AI Foundry Setup
###############################################################################
echo
echo "📑 AI Foundry Setup…"
{
  echo "🚀 Running config.aifoundry.aifoundry_setup…"
  python -m config.aifoundry.setup
  echo "✅ AI Foundry setup script finished."
} || {
  echo "❗️ Error during AI Foundry setup. Skipping it."
}

###############################################################################
# 2) Container Apps Setup
###############################################################################
echo
echo "🔍 ContainerApp setup…"
{
  echo "🚀 Running config.containerapps.setup…"
  python -m config.containerapps.setup
  echo "✅ Container Apps setup script finished."
} || {
  echo "❗️ Error during Container Apps setup. Skipping it."
}

###############################################################################
# 3) AI Search Setup
###############################################################################
echo
echo "🔍 AI Search setup…"
{
  echo "🚀 Running config.search.setup…"
  python -m config.search.setup
  echo "✅ Search setup script finished."
} || {
  echo "❗️ Error during Search setup. Skipping it."
}

###############################################################################
# Cleaning up
###############################################################################
echo
echo "🧹 Cleaning Python environment up…"
# `deactivate` only restores shell variables (PATH, PS1) — it deletes nothing.
# Since the script is ending, there is nothing to restore. We skip it and
# go straight to removing the venv directory.
# python3's shutil.rmtree handles locked files and open __pycache__ handles
# (common on macOS with Python 3.12+) without raising, unlike `rm -rf`.
python3 -c "import shutil; shutil.rmtree('config/.venv_temp', ignore_errors=True)"

echo
echo "✅ postProvisioning completed."
