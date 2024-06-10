# Troubleshooting  
   
**Powershell 7+ is not installed** (Windows only)
   
*Symptoms:*  
   
ERROR: failed running pre hooks: 'prepackage' hook failed with exit code: '1', Path: 'scripts\fetchComponents.ps1'. : exit code: 1, stdout: , stderr: 'pwsh' is not recognized as an internal or external command,  
operable program or batch file.  
   
*Cause:*
   
You do not have the correct Powershell version. You need to install the appropriate version of PowerShell on the machine that azd up is running on.  
   
**Azure OpenAI model is not available in the selected region.**
   
*Symptoms:*  
   
ERROR: deployment failed: failing invoking action 'provision', error deploying infrastructure: deploying to subscription:  
Deployment Error Details:  
RetryableError: A retryable error occurred.  
   
*Cause:*  
   
The error message indicates that the deployment failed to provision an infrastructure resource. It may have occurred with another resource that is not Azure OpenAI, but this is a common cause. Therefore, in this case, [check if the gpt model selected in the deployment is available in the selected region](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models). You can check the gpt model selected in the deployment looking at the chatGptModelName and chatGptModelVersion parameters of the main.parameters.json file.  
   
**The tenant used by azd is different from the tenant used by another authentication method**  
   
*Symptoms:*  
  
  (x) Failed: Deploying service dataIngest  
   
ERROR: failed deploying service 'dataIngest': failed invoking event handlers for 'postdeploy', 'postdeploy' hook failed with exit code: '1',  
...  
azure.core.exceptions.ClientAuthenticationError: (InvalidAuthenticationTokenTenant) The access token is from the wrong issuer ..  
Code: InvalidAuthenticationTokenTenant  
Message: The access token is from the wrong issuer ...  
   
*Cause:*  
   
The setup.py, which is in charge of setting up the AI Search service, utilizes the DefaultAzureCredential class to obtain the necessary access credentials for Azure. It does so in a specific sequence as follows:

1. A service principal configured by environment variables.  
2. WorkloadIdentityCredential.  
3. An Azure managed identity.  
4. On Windows only, an available AZURE_USERNAME.  
5. The identity currently logged in to the Azure CLI (az).  
6. The identity currently logged in to Azure PowerShell.  
7. The identity currently logged in to the Azure Developer CLI (azd).  
   
In this case, a method with higher precedence than azd, for example az, is logged into a different tenant than what was initially logged in with `azd auth login` and you should update this method to the same tenant used in `azd auth login`.  
   
**Zero-trust deployment from a machine outside its vnet**  
   
*Symptoms:*  
   
Deploying services (azd deploy)  
  
  (x) Failed: Deploying service dataIngest  

ERROR: failed deploying service 'dataIngest': failing invoking action 'deploy', POST https://...scm.azurewebsites.net/api/zipdeploy  
<span>--------------------------------------------------------------------------------</span>  
RESPONSE 403: 403 Ip Forbidden  
ERROR CODE UNAVAILABLE  
   
*Cause:*  
   
For deployment of the zero trust components, it is necessary to perform it from the VM created during the process. 