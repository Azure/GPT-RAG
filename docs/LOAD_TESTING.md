# TODO: Passo a passo para testar com LOAD TESTING

### Planning your test

CREATE THE SCENARIO FOR THE GOVERNMENT CASE

CREATE A TEST DIAGRAM

### Preparation steps

DISCUSS DATA PREPARATION

DISCUSS SETUP AND MONITORING PART

- Prerequisites
    - An Azure Account with an active subscription
    - Install Azure CLI

1. [Create an Azure Load Testing Resource](https://learn.microsoft.com/en-us/azure/load-testing/quickstart-create-and-run-load-test)
2. [Assign a system-assigned identity](https://learn.microsoft.com/en-us/azure/load-testing/how-to-use-a-managed-identity) to the load testing resource created above.
3. [Add a new access policy](https://learn.microsoft.com/en-us/azure/key-vault/general/assign-access-policy) in the Key Vault for the Load Testing identity using the Object(principal)ID, granting Get and List permissions for secrets.

### Configure your test suite

EXPLICAR JMETER

1. Configure `jmeter/user.properties`
2. Configure `jmeter/runtest.properties`

### Executing the test

run `./run-test.sh` in `jmeter` folder

### Analyzing Load Test Results

MONITOR AND LOAD TESTING RESUTS