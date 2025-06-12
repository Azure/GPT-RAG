#!/usr/bin/env bash
set -euo pipefail

# avoid unbound-variable errors by setting defaults
: "${deployAppConfig:=true}"
: "${deploySearchService:=true}"
: "${networkIsolation:=false}"

echo "🔧 Running post-provision steps…"

echo "📋 Current environment variables:"
for v in deployAppConfig deploySearchService networkIsolation ; do
  printf "  %s=%s\n" "$v" "${!v:-<unset>}"
done

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
# 1) App Configuration Setup
###############################################################################
echo 
echo "📑 Seeding App Configuration…"
{

  echo "🚀 Running scripts.appconfig.seed_config…"
  python -m config.appconfig.setup
  echo "✅ App Configuration script finished."
} || {
  echo "❗️ Error during App Configuration Setup. Skipping it."
}

###############################################################################
# 2) AI Foundry Setup
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
# 3) AI Search Setup
###############################################################################
echo
if [[ "${deploySearchService,,}" == "true" ]]; then
  echo "🔍 AI Search setup…"
  {
    echo "🚀 Running config.search.setup…"
    python -m config.search.setup
    echo "✅ Search setup script finished."
  } || {
    echo "❗️ Error during Search setup. Skipping it."
  }
else
  echo "⚠️  Skipping AI Search setup (deploySearchService is not 'true')."
fi

###############################################################################
# 4) Zero Trust Information
###############################################################################
echo 
if [[ "${networkIsolation,,}" == "true" ]]; then
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