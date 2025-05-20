#!/usr/bin/env bash
set -euo pipefail

# avoid unbound-variable errors by setting defaults
: "${AZURE_INSTALL_AOAI:=false}"
: "${AZURE_INSTALL_SEARCH_SERVICE:=false}"
: "${AZURE_INSTALL_AI_FOUNDRY:=false}"
: "${AZURE_CONFIGURE_RBAC:=false}"
: "${AZURE_NETWORK_ISOLATION:=false}"

echo "🔧 Running post-provision steps…"

echo "📋 Current environment variables:"
for v in AZURE_INSTALL_AOAI AZURE_INSTALL_SEARCH_SERVICE AZURE_INSTALL_AI_FOUNDRY AZURE_CONFIGURE_RBAC AZURE_NETWORK_ISOLATION; do
  printf "  %s=%s\n" "$v" "${!v:-<unset>}"
done

###############################################################################
# Setup Python environment
###############################################################################
echo "📦 Creating temporary venv…"
python -m venv config/.venv_temp
source config/.venv_temp/bin/activate

echo "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r config/requirements.txt

###############################################################################
# 1) App Configuration Setup
###############################################################################
echo 
echo "📑 Seeding App Configuration…"
{

  echo "🚀 Running scripts.appconfig.seed_config…"
  python -m config.appconfig.seed_config
  echo "✅ App Configuration script finished."
} || {
  echo "❗️ Error during App Configuration Setup. Skipping it."
}

###############################################################################
# 2) RBAC Setup
###############################################################################
echo 
if [[ "${AZURE_CONFIGURE_RBAC,,}" == "true" ]]; then
  echo "📑 RBAC Setup…"
  {
    echo "🚀 Running config.rbac.setup…"
    python -m config.rbac.rbac_setup
    echo "✅ RBAC setup script finished."
  } || {
    echo "❗️ Error during RBAC setup. Skipping it."
  }
else
  echo "⚠️  Skipping RBAC setup (AZURE_CONFIGURE_RBAC is not 'true')."
fi

###############################################################################
# 3) AOAI Setup
###############################################################################
echo 
if [[ "${AZURE_INSTALL_AOAI,,}" == "true" ]]; then
  echo "📑 AOAI Setup…"
  {
    echo "🚀 Running config.aoai.raipolicies (Applying RAI policies)…"
    python -m config.aoai.raipolicies
    echo "✅ AOAI setup script finished."
  } || {
    echo "❗️ Error during AOAI setup. Skipping it."
  }
else
  echo "⚠️  Skipping AOAI setup (AZURE_INSTALL_AOAI is not 'true')."
fi

###############################################################################
# 4) AI Foundry Setup
###############################################################################
echo 
if [[ "${AZURE_INSTALL_AI_FOUNDRY,,}" == "true" ]]; then
  echo "📑 AI Foundry Setup…"
  {
    echo "🚀 Running config.aifoundry.aifoundry_setup…"
    python -m config.aifoundry.aifoundry_setup
    echo "✅ AI Foundry setup script finished."
  } || {
    echo "❗️ Error during AI Foundry setup. Skipping it."
  }
else
  echo "⚠️  Skipping AI Foundry setup (AZURE_INSTALL_AI_FOUNDRY is not 'true')."
fi

# ###############################################################################
# # 5) AI Search Setup
# ###############################################################################
echo 
if [[ "${AZURE_INSTALL_SEARCH_SERVICE,,}" == "true" ]]; then
  echo "🔍 AI Search setup…"
  {
    echo "🚀 Running config.search.setup…"
    python -m config.search.search_setup
    echo "✅ Search setup script finished."
  } || {
    echo "❗️ Error during Search setup. Skipping it."
  }
else
  echo "⚠️  Skipping AI Search setup (AZURE_INSTALL_SEARCH_SERVICE is not 'true')."
fi

# ###############################################################################
# # 5) Container Apps Setup
# ###############################################################################
echo 
if [[ "${AZURE_INSTALL_CONTAINER_APPS,,}" == "true" ]]; then
  echo "🔍 Container Apps setup…"
  {
    echo "🚀 Running config.containerapps.capps_setup…"
    python -m config.containerapps.capp_setup
    echo "✅ Container Apps setup script finished."
  } || {
    echo "❗️ Error during Container Apps setup. Skipping it."
  }
else
  echo "⚠️  Skipping Container Apps setup (AZURE_INSTALL_CONTAINER_APPS is not 'true')."
fi

###############################################################################
# 7) Zero Trust Information
###############################################################################
echo 
if [[ "${AZURE_NETWORK_ISOLATION,,}" == "true" ]]; then
  echo "🔒 Access the Zero Trust bastion:"
  echo "  VM: $AZURE_VM_NAME"
  echo "  User: $AZURE_VM_USER_NAME"
  echo "  Credentials: $AZURE_BASTION_KV_NAME/$AZURE_VM_KV_SEC_NAME"
else
  echo "🚧 Zero Trust not enabled; provisioning Standard architecture."
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