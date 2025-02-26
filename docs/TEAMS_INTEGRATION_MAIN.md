# Guide for Building a Teams App Interface for the Enterprise GPT-RAG Solution Accelerator

## Introduction
This is a guide for building a Teams App Interface for the Enterprise GPT-RAG Solution Accelerator using Teams toolkit.

## Key Solution Components
The following Azure resources will be deployed in addition to those already deployed in the Enterprise RAG Solution Accelerator.
- Azure Bot Framework service
- Azure App Service Plan & Azure App Service
- Managed Identity

## Prerequisites
Before proceeding with the steps in the subsequent sections, ensure you have completed the following:
- An Azure subscription to deploy the required resources.
- A Microsoft 365 account. Read more on developer program that can be used for testing purposes. [here](https://learn.microsoft.com/en-us/microsoftteams/platform/toolkit/tools-prerequisites#microsoft-365-developer-program).
- The Enterprise GPT-RAG Solution Accelerator deployed in your Azure subscription.
- For publishing, access to a Teams admin who can approve the app deployment within your organization. Alternatively, you can test locally on your development machine and/or use [custom upload](https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/deploy-and-publish/apps-upload) option if enabled for your organization.
- Note: When deploying Azure resources for the Teams app, such as the App Service Plan and App Service, you can utilize the resources already provisioned in the GPT-RAG Solution Accelerator.
- Note: The App Service uses a public endpoint for the Teams App to connect to the service.

Set up the following prerequisites on the machine to be used for development:
- Download and install [Visual Studio Code](https://code.visualstudio.com/Download).
- Install [NodeJS](https://nodejs.org/) version 16 or later.

## Step 1: [Create a new Teams App](TEAMS_INTEGRATION_STEP1.md).

## Step 2: [Connect to GPT-RAG Orchestrator and test locally](TEAMS_INTEGRATION_STEP2.md).

## Step 3: [Provision and Deploy the Azure resources for the Teams App](TEAMS_INTEGRATION_STEP3.md).

## Step 4: [Build the Teams App](TEAMS_INTEGRATION_STEP4.md).

## Step 5: [Publish the Teams App](TEAMS_INTEGRATION_STEP5.md).

## External Resources
- [Microsoft Teams Toolkit Overview](https://learn.microsoft.com/en-us/microsoftteams/platform/toolkit/teams-toolkit-fundamentals).
- [Visual Studio Code](https://code.visualstudio.com/Download).
- [Install Teams Toolkit](https://learn.microsoft.com/en-us/microsoftteams/platform/toolkit/install-teams-toolkit?tabs=vscode).
- [Microsoft 365 developer program](https://learn.microsoft.com/en-us/microsoftteams/platform/toolkit/tools-prerequisites#microsoft-365-developer-program).

