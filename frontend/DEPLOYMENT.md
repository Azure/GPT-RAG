# GPT-RAG Frontend Deployment Guide

This guide explains how to deploy the GPT-RAG frontend as part of the overall GPT-RAG solution accelerator.

## Architecture Integration

The frontend integrates with the GPT-RAG solution architecture as follows:

```
┌─────────────────┐
│   User Browser  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Frontend App   │  ← This Application
│ (Container App) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Orchestrator   │
│ (Container App) │
└────────┬────────┘
         │
         ▼
    ┌────┴────┐
    │         │
    ▼         ▼
┌──────┐  ┌──────────┐
│ AI   │  │ AI Search│
│OpenAI│  │          │
└──────┘  └──────────┘
```

## Prerequisites

- Azure subscription with GPT-RAG infrastructure deployed
- Azure Container Registry
- Azure Container Apps environment
- Azure App Configuration

## Deployment Methods

### Method 1: Azure DevOps / GitHub Actions (Recommended)

#### 1. Build and Push Docker Image

```bash
# Login to Azure Container Registry
az acr login --name <your-acr-name>

# Build and tag the image
docker build -t <your-acr-name>.azurecr.io/gpt-rag-frontend:latest .

# Push to ACR
docker push <your-acr-name>.azurecr.io/gpt-rag-frontend:latest
```

#### 2. Update Container App

The frontend Container App should already be provisioned by the main infrastructure. Update it with:

```bash
az containerapp update \
  --name <frontend-app-name> \
  --resource-group <resource-group> \
  --image <your-acr-name>.azurecr.io/gpt-rag-frontend:latest
```

### Method 2: Using Azure CLI

Complete deployment from scratch:

```bash
# Variables
RESOURCE_GROUP="<your-resource-group>"
LOCATION="<azure-region>"
ACR_NAME="<your-acr-name>"
CONTAINER_APP_ENV="<container-apps-environment>"
FRONTEND_APP_NAME="ca-frontend-<your-suffix>"
ORCHESTRATOR_ENDPOINT="<orchestrator-endpoint>"

# Create Container App
az containerapp create \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --image $ACR_NAME.azurecr.io/gpt-rag-frontend:latest \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --env-vars \
    ORCHESTRATOR_ENDPOINT=$ORCHESTRATOR_ENDPOINT
```

### Method 3: Integration with Existing Infrastructure

The GPT-RAG infrastructure already defines a frontend container app in `infra/main.parameters.json`:

```json
{
  "name": null,
  "external": true,
  "service_name": "frontend",
  "profile_name": "main",
  "min_replicas": 1,
  "max_replicas": 1,
  "canonical_name": "FRONTEND_APP"
}
```

To deploy this frontend:

1. **Update the manifest**: Ensure `infra/manifest.json` points to your frontend repo or build.

2. **Build and push**: The `scripts/preDeploy.ps1` or `scripts/preDeploy.sh` scripts handle building and pushing container images.

3. **Run deployment**:
```bash
# Windows
.\scripts\preDeploy.ps1

# Linux/Mac
./scripts/preDeploy.sh
```

## Configuration

### Environment Variables

The frontend reads configuration from:

1. **Build-time** (via Vite):
   - `VITE_ORCHESTRATOR_ENDPOINT`: Set during build for static configuration

2. **Runtime** (via nginx or API):
   - `ORCHESTRATOR_ENDPOINT`: Proxy pass endpoint in nginx.conf

### Azure App Configuration

The frontend can also read dynamic configuration from Azure App Configuration:

- `FRONTEND_APP_ENDPOINT`: Your frontend URL
- `ORCHESTRATOR_APP_ENDPOINT`: The orchestrator service URL
- `ENABLE_USER_FEEDBACK`: Feature flag for feedback
- `USER_FEEDBACK_RATING`: Enable detailed ratings

## Health Monitoring

The frontend includes a health check endpoint:

```bash
curl https://<your-frontend-url>/health
```

Response: `healthy`

## Scaling Configuration

### Auto-scaling Rules

```bash
az containerapp update \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 1 \
  --max-replicas 10 \
  --scale-rule-name http-rule \
  --scale-rule-type http \
  --scale-rule-http-concurrency 50
```

### Resource Limits

Recommended resources per instance:
- **CPU**: 0.5-1.0 cores
- **Memory**: 1.0 GB
- **Min Replicas**: 1
- **Max Replicas**: 3-10 (based on load)

## Security

### Network Isolation

For Zero Trust architecture:

1. **Private endpoints**: Enable if required by your security policy
2. **VNet integration**: Connect to your Azure VNet
3. **NSG rules**: Configure Network Security Groups

```bash
az containerapp update \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-ingress \
  --ingress internal \
  --target-port 80
```

### Authentication

To enable Azure AD authentication:

```bash
az containerapp auth update \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --enabled true \
  --action AllowAnonymous \
  --aad-client-id <client-id> \
  --aad-client-secret-setting-name <secret-name> \
  --aad-tenant-id <tenant-id>
```

## Monitoring and Logging

### Application Insights

Connect to Application Insights:

```bash
az containerapp update \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-dapr \
  --dapr-app-id gpt-rag-frontend \
  --env-vars \
    APPLICATIONINSIGHTS_CONNECTION_STRING=<connection-string>
```

### Log Analytics

View logs:

```bash
az containerapp logs show \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --follow
```

## Troubleshooting

### Common Issues

#### 1. Container fails to start

Check logs:
```bash
az containerapp logs show --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP
```

Verify image:
```bash
az acr repository show-tags --name $ACR_NAME --repository gpt-rag-frontend
```

#### 2. Cannot connect to orchestrator

- Verify `ORCHESTRATOR_ENDPOINT` environment variable
- Check network connectivity between container apps
- Ensure orchestrator is running and healthy

#### 3. 404 errors on routes

- Ensure nginx.conf is correctly configured for SPA routing
- Verify the `try_files` directive includes `/index.html` fallback

### Debug Mode

For local testing with Docker:

```bash
# Run frontend locally
docker build -t gpt-rag-frontend:dev .
docker run -p 3000:80 \
  -e ORCHESTRATOR_ENDPOINT=http://host.docker.internal:8000 \
  gpt-rag-frontend:dev
```

### Network Diagnostics

Test connectivity from frontend to orchestrator:

```bash
az containerapp exec \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --command "/bin/sh"

# Inside the container
wget -O- $ORCHESTRATOR_ENDPOINT/health
```

## Rollback

To rollback to a previous version:

```bash
# List revisions
az containerapp revision list \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP

# Activate previous revision
az containerapp revision activate \
  --name $FRONTEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --revision <revision-name>
```

## Performance Optimization

### CDN Integration

For better performance, integrate with Azure Front Door:

```bash
# Create Front Door profile
az afd profile create \
  --profile-name gpt-rag-fd \
  --resource-group $RESOURCE_GROUP \
  --sku Premium_AzureFrontDoor

# Add frontend as origin
az afd origin create \
  --resource-group $RESOURCE_GROUP \
  --profile-name gpt-rag-fd \
  --origin-group-name frontend-origins \
  --origin-name frontend-app \
  --host-name <frontend-app-url> \
  --origin-host-header <frontend-app-url>
```

### Caching

Static assets are cached with long expiration times. Update nginx.conf if needed:

```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## Cost Optimization

1. **Scale down during off-hours**: Set min replicas to 0 for dev/test environments
2. **Use Consumption plan**: If traffic is sporadic
3. **Optimize image size**: Multi-stage builds reduce costs

## Support

For issues specific to the frontend, check:
- Frontend logs in Container Apps
- Browser console for client-side errors
- Network tab for API communication issues

For architectural questions, refer to the main GPT-RAG documentation.

