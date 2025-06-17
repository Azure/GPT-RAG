// This module exists solely to pass the `containerAppsList` parameter through as an output,
// allowing you to assign the entire array directly as a key-value in your App Configuration.
param containerAppsList array

output containerAppsList array = containerAppsList

// prepare the output for App Configuration
output containerAppsEndpoints array = [
  for app in containerAppsList: { 
    name: '${app.canonical_name}_ENDPOINT', value: 'https://${app.fqdn}', label: 'gpt-rag', contentType: 'text/plain' 
  }
]
