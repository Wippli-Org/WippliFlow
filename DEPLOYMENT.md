# WippliFlow Deployment Guide

## Automatic Deployment from GitHub

This repository is configured for automatic deployment to Azure Container Apps using GitHub Actions.

### Setup Instructions

1. **Add Azure Credentials to GitHub Secrets**
   - Go to https://github.com/Wippli-Org/WippliFlow/settings/secrets/actions
   - Click "New repository secret"
   - Name: `AZURE_CREDENTIALS`
   - Value: See AZURE_CREDENTIALS.json file (not committed to git)

2. **How Deployment Works**
   - Every push to `main` branch automatically:
     - Builds a Docker image with WippliFlow branding
     - Pushes to GitHub Container Registry (ghcr.io/wippli-org/wippliflow)
     - Deploys to Azure Container Apps
   - You can also manually trigger deployment from GitHub Actions tab

3. **Azure Resources**
   - **Resource Group**: wippliflow-au-rg (Australia East)
   - **Container App**: wippliflow
   - **Production URL**: https://wippliflow.politecliff-e2f2af18.australiaeast.azurecontainerapps.io

### WippliFlow Branding

Custom branding is applied in:
- **Theme File**: packages/server/api/src/app/flags/theme.ts
- **Primary Color**: #513091 (Wippli Purple)
- **Logos**: Hosted on Azure Blob Storage (wippliragstore)
  - Favicon: https://wippliragstore.blob.core.windows.net/wippli-documents/wippliflow/favicon.png
  - Logo: https://wippliragstore.blob.core.windows.net/wippli-documents/wippliflow/logo-light.svg

### Making Changes

1. Edit code locally
2. Commit and push to `main` branch
3. GitHub Actions automatically builds and deploys
4. Changes live in ~15 minutes

### Monitoring

- **GitHub Actions**: https://github.com/Wippli-Org/WippliFlow/actions
- **Azure Portal**: https://portal.azure.com
- **Application Logs**: `az containerapp logs show --name wippliflow --resource-group wippliflow-au-rg --tail 100`
