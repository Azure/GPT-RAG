# Troubleshooting  

### **Frontend error message: "I'm sorry, I had a problem with the request..."**

*Symptoms:*  

Users see an error message stating: "I'm sorry, I had a problem with the request. Please report the error to the support team. SyntaxError: Failed to execute 'json' on 'Response': Unexpected end of JSON input."

*Cause:*

This issue typically occurs when the orchestrator does not send a response to the frontend.

*Resolution:*

Please check the orchestrator's log stream for any specific errors. If the issue persists, feel free to reopen it.
      
---

### **Powershell 7+ is not installed** (Windows only)
   
*Symptoms:*  
   
ERROR: failed running pre hooks: 'prepackage' hook failed with exit code: '1', Path: 'scripts\fetchComponents.ps1'. : exit code: 1, stdout: , stderr: 'pwsh' is not recognized as an internal or external command,  
operable program or batch file.  
   
*Cause:*
   
You do not have the correct Powershell version. You need to install the appropriate version of PowerShell on the machine that azd up is running on.  
   
---

### **Azure OpenAI model is not available in the selected region.**
   
*Symptoms:*  
   
ERROR: deployment failed: failing invoking action 'provision', error deploying infrastructure: deploying to subscription:  
Deployment Error Details:  
RetryableError: A retryable error occurred.  
   
*Cause:*  
   
The error message indicates that the deployment failed to provision an infrastructure resource. It may have occurred with another resource that is not Azure OpenAI, but this is a common cause. Therefore, in this case, [check if the gpt model selected in the deployment is available in the selected region](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models). You can check the gpt model selected in the deployment looking at the chatGptModelName and chatGptModelVersion parameters of the main.parameters.json file.  
   
---

### **The tenant used by azd is different from the tenant used by another authentication method**  
   
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
   
---

### **Zero-trust deployment from a machine outside its vnet**  
   
*Symptoms:*  
   
Deploying services (azd deploy)  
  
  (x) Failed: Deploying service dataIngest  

ERROR: failed deploying service 'dataIngest': failing invoking action 'deploy', POST https://...scm.azurewebsites.net/api/zipdeploy  
<span>--------------------------------------------------------------------------------</span>  
RESPONSE 403: 403 Ip Forbidden  
ERROR CODE UNAVAILABLE  
   
*Cause:*  
   
For deployment of the zero trust components, it is necessary to perform it from the VM created during the process. 

---

### **SQL Database is Unavailable or Autopaused**

*Symptoms:*

```
2024-11-17 20:32:55,910 - ERROR - root - Failed to connect to the database with Azure AD token authentication: ('HY000', "[HY000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Database 'databasename' on server 'servername.database.windows.net' is not currently available.  Please retry the connection later.  If the problem persists, contact customer support, and provide them the session tracing ID of '{3B6C6E7D-744D-49D5-B152-8418ADA28174}'. (40613) (SQLDriverConnect)")
```

*Cause:*

The SQL Database might be in an **autopause** state or temporarily unavailable, preventing connections.

*Solution:*

1. **Check Database Status:**
   - Navigate to the [Azure Portal](https://portal.azure.com/) and go to your SQL Database instance.
   - Verify if the database is paused or in an unavailable state.

2. **Resume the Database:**
   - If the database is autopaused, manually resume it by selecting the **Resume** option in the Azure Portal.
   - Wait a few minutes for the database to become available.

3. **Retry Connection:**
   - After ensuring the database is active, attempt to reconnect.
   - If the issue persists, consider contacting Azure Support and provide the session tracing ID for further assistance.

**Error Authenticating to VM via Bastion**

*Symptoms*
- Unable to log into the VM through Bastion.  
- The generated password does not work, or Bastion login fails when using the password option.  

*Cause*  
During zero-trust deployment, the VM password may not be properly generated or assigned, leading to authentication issues.

*Solution*

1. **Reset the VM Password Manually**:  
   - Open the [Azure Portal](https://portal.azure.com/).  
   - Navigate to the VM's page.  
   - Go to **Help + Support** > **Reset password**.  
   - Reset the password for the user account.  

2. **Log in via Bastion**:  
   - Attempt to log into the VM using Bastion.  
   - When prompted, do not select the option to use the password stored in Key Vault.  

3. **Optional: Update the Key Vault Secret for Future Access**:  
   - Update the secret **`vmUserInitialPassword`** in the Key Vault with the newly reset password.
   - This ensures the stored password matches the reset one, simplifying future Bastion logins.

**Client IP Address Not Allowed by SQL Database Firewall** (When using NL2SQL orchestration)

*Symptoms:*

```
2024-11-17 20:36:26,592 - ERROR - root - Failed to connect to the database with Azure AD token authentication: ('42000', "[42000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Cannot open server 'databasename' requested by the login. Client with IP address '999.999.999.999' is not allowed to access the server.  To enable access, use the Azure Management Portal or run sp_set_firewall_rule on the master database to create a firewall rule for this IP address or address range.  It may take up to five minutes for this change to take effect. (40615) (SQLDriverConnect)")
```

*Cause:*

Your client’s IP address is not included in the SQL Database server's firewall rules, blocking access.

*Solution:*

1. **Add IP Address to Firewall Rules:**
   - Go to the [Azure Portal](https://portal.azure.com/) and navigate to your SQL Server instance.
   - Select **Firewall and virtual networks**.
   - Click on **Add client IP** to automatically add your current IP address, or manually enter the specific IP address or range that needs access.

2. **Using PowerShell:**
   - Alternatively, you can use PowerShell to add a firewall rule:
     ```powershell
     # Replace the placeholders with your server name, rule name, and IP range
     $serverName = "mydatabase0915"
     $ruleName = "AllowMyIP"
     $startIp = "999.999.999.999"
     $endIp = "999.999.999.999"

     New-AzSqlServerFirewallRule -ResourceGroupName "YourResourceGroup" -ServerName $serverName -FirewallRuleName $ruleName -StartIpAddress $startIp -EndIpAddress $endIp
     ```

3. **Wait for Propagation:**
   - Firewall changes may take up to five minutes to take effect. Wait for this period before attempting to reconnect.

4. **Verify Access:**
   - After adding the IP address, try connecting to the database again to ensure that access is now permitted.
