param accountName string
param accountCapHost string

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
   name: accountName
}

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-06-01' = {
   name: accountCapHost
   parent: account
   properties: {
     capabilityHostKind: 'Agents'
   }
}
