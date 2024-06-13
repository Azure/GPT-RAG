### Troubleshooting  
   
**Powershell 7+ with AZ module are not installed** (Windows only)
   
*Symptoms:*  
   
ERROR: failed running pre/post hooks: 'prepackage' hook failed with exit code: '1', Path: 'scripts\fetchComponents.ps1'. : exit code: 1, stdout: , stderr: 'pwsh' is not recognized as an internal or external command,  
operable program or batch file.  
   
*Cause:*
   
You do not have the correct Powershell version. You need to install the appropriate version of PowerShell on the machine that azd up is running on.\
You do not have [AZ PowerShell module](https://learn.microsoft.com/en-us/powershell/azure/what-is-azure-powershell?view=azps-11.6.0#the-az-powershell-module) installed. You need to install AZ PowerShell module on the machine `Install-Module -Name Az -Repository PSGallery -Force` that azd up is running on .
   
**Azure OpenAI model is not available in the selected region.**
   
*Symptoms:*  
   
ERROR: deployment failed: failing invoking action 'provision', error deploying infrastructure: deploying to subscription:  
Deployment Error Details:  
RetryableError: A retryable error occurred.  
   
*Cause:*  
   
The error message indicates that the deployment failed to provision an infrastructure resource. It may have occurred with another resource that is not Azure OpenAI, but this is a common cause. Therefore, in this case, [check if the gpt model selected in the deployment is available in the selected region](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models). You can check the gpt model selected in the deployment looking at the chatGptModelName and chatGptModelVersion parameters of the main.parameters.json file.  

**The subscription's home tenant differs from the tenant of the identity executing the 'azd' command**

*Symptoms:*

While running post-provisioning scripts, you encounter the following error:

`ERROR: No subscription found. Run 'az account set' to select a subscription.`

or

`ERROR: Get-AzAccessToken: Run Connect-AzAccount to login.`

*Cause:*

This issue can occur if you have subscriptions whose home tenant is not the same as the tenant where your user is registered and authenticated.
In this case, using `azd auth login` may not sufficient to enable your subscription for the Azure CLI commands we run in the azd hooks.
You will need to log in using `az login --tenant TENANT_ID` or `Connect-AzAccount -Tenant 'TENANT_ID' -SubscriptionId 'SUBSCRIPTION_ID'` (PowerShell) to run the post-provisioning scripts.

**Your subscription has policies that prevent you from running az commands with your user account**

*Symptoms:*

When running post-provisioning scripts, you encounter errors like this one (external users are not allowed to access resources):

`ERROR: AADSTS530004: AcceptCompliantDevice setting isn't configured for this organization. The admin needs to configure this setting to allow external users access to protected resources. Trace ID: c6d5b92a-0559-4477-a7e7-e42ae19d3200 Correlation ID: b95cc6b5-4bef-4c35-9261-688c481f8dbc Timestamp: 2024-06-03 20:25:56Z`

*Cause:*

In this case, you can choose to create a service principal, grant it contributor permission on the subscription, and log in with the service principal using the [AZD CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-auth-login),  [AZ CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-service-principal) and [Connect-AzAccount](https://learn.microsoft.com/en-us/powershell/azure/authenticate-noninteractive?view=azps-12.0.0&viewFallbackFrom=azps-11.1.0#password-based-authentication) if using powershell (windows).

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
