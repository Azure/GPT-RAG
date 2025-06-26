#!/usr/bin/env bash
set -euo pipefail


echo "🔧 Running post-provision steps…"
echo 

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
# Environment Variables
###############################################################################

# avoid unbound-variable errors by setting defaults
: "${DEPLOY_CONTAINER_APPS:=true}"
: "${DEPLOY_SEARCH_SERVICE:=true}"
: "${NETWORK_ISOLATION:=false}"
: "${USE_UAI:=false}"

echo "📋 Current environment variables:"
for v in  APP_CONFIG_ENDPOINT DEPLOY_CONTAINER_APPS DEPLOY_SEARCH_SERVICE NETWORK_ISOLATION USE_UAI ; do
  printf "  %s=%s\n" "$v" "${!v:-<unset>}"
done

###############################################################################
# 1) AI Foundry Setup
###############################################################################
# echo 
# echo "📑 AI Foundry Setup…"
# {
#   echo "🚀 Running config.aifoundry.aifoundry_setup…"
#   python -m config.aifoundry.setup
#   echo "✅ AI Foundry setup script finished."
# } || {
#   echo "❗️ Error during AI Foundry setup. Skipping it."
# }

###############################################################################
# 2) Container Apps Setup
# ###############################################################################
# echo
# if [[ "${DEPLOY_CONTAINER_APPS,,}" == "true" ]]; then
#   echo "🔍 ContainerApp setup…"
#   {
#     echo "🚀 Running config.containerapps.setup…"
#     python -m config.containerapps.setup
#     echo "✅ Container Apps setup script finished."
#   } || {
#     echo "❗️ Error during Container Apps setup. Skipping it."
#   }
# else
#   echo "⚠️  Container Apps setup (DEPLOY_CONTAINER_APPS is not 'true')."
# fi

###############################################################################
# 3) AI Search Setup
###############################################################################
echo
if [[ "${DEPLOY_SEARCH_SERVICE,,}" == "true" ]]; then
  echo "🔍 AI Search setup…"
  {
    echo "🚀 Running config.search.setup…"
    python -m config.search.setup
    echo "✅ Search setup script finished."
  } || {
    echo "❗️ Error during Search setup. Skipping it."
  }
else
  echo "⚠️  Skipping AI Search setup (DEPLOY_SEARCH_SERVICE is not 'true')."
fi

###############################################################################
# 4) Zero Trust Information
###############################################################################
echo 
if [[ "${NETWORK_ISOLATION,,}" == "true" ]]; then
  echo "🔒 Access the Zero Trust bastion"
else
  echo "🚧 Zero Trust not enabled; provisioning Basic architecture."
fi

echo 
echo "✅ postProvisioning completed."

###############################################################################
# Cleaning up
###############################################################################
echo 
echo "🧹 Cleaning Python environment up…"
deactivate
rm -rf config/.venv_temp