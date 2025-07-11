#!/usr/bin/env bash
set -euo pipefail
echo "🔧 Running post-provision steps…"
echo 

###############################################################################
# Zero Trust Information
###############################################################################
echo
if [[ "${NETWORK_ISOLATION,,}" == "true" ]]; then
  echo "🔒 Zero Trust enabled."
  echo "Access to Azure resources is restricted to the VNet."
  echo "Ensure you run scripts/postProvision.sh from within the VNet."
  echo "If you’re using a local machine, make sure you have a VPN connection to the VNet."
  echo "You can also use the Test VM to access the environment and complete the setup."
  read -p "Are you running this script from inside the VNet or via VPN? [Y/n]: " answer
  if [[ ! "${answer,,}" =~ ^y ]]; then
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
# ###############################################################################
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
deactivate
rm -rf config/.venv_temp

echo 
echo "✅ postProvisioning completed."