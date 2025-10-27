#!/bin/bash
# WippliFlow - Azure Container Apps Deployment Script
# DO NOT RUN WITHOUT CONFIGURING VARIABLES BELOW
# This script deploys WippliFlow to Azure Container Apps in laoo-uk-rg

set -e

# ============================================================================
# CONFIGURATION - MODIFY THESE VALUES
# ============================================================================

RESOURCE_GROUP="laoo-uk-rg"
LOCATION="uksouth"
CONTAINER_APP_ENV="laoo-uk-env"
CONTAINER_APP_NAME="wippliflow"

# Database Configuration (using existing PostgreSQL server)
POSTGRES_SERVER="metabase-sql-minimal"
POSTGRES_DATABASE="wippliflow_production"
POSTGRES_USERNAME="wippliflow_user"
POSTGRES_PASSWORD="CHANGE_ME_SECURE_PASSWORD"  # Generate secure password

# Redis Configuration (will be created)
REDIS_NAME="wippliflow-redis"
REDIS_SKU="Basic"
REDIS_VM_SIZE="c0"

# WippliFlow Configuration
CONTAINER_IMAGE="ghcr.io/activepieces/activepieces:latest"  # Or use Wippli-Org build
FRONTEND_URL="https://flow.wippli.com"  # Change to your custom domain
WEBHOOK_URL="https://api.wippli.com/wippliflow/webhook"  # Wippli API webhook endpoint

# Generate these with: openssl rand -hex 32
ENCRYPTION_KEY="CHANGE_ME_32_HEX_CHARS"  # 64 characters (32 bytes hex)
JWT_SECRET="CHANGE_ME_32_HEX_CHARS"      # 64 characters (32 bytes hex)

# ============================================================================
# VALIDATION
# ============================================================================

echo "🔍 Validating configuration..."

if [[ "$POSTGRES_PASSWORD" == "CHANGE_ME_SECURE_PASSWORD" ]]; then
    echo "❌ ERROR: POSTGRES_PASSWORD not set"
    echo "Generate a secure password and update the script"
    exit 1
fi

if [[ "$ENCRYPTION_KEY" == "CHANGE_ME_32_HEX_CHARS" ]]; then
    echo "❌ ERROR: ENCRYPTION_KEY not set"
    echo "Generate with: openssl rand -hex 32"
    exit 1
fi

if [[ "$JWT_SECRET" == "CHANGE_ME_32_HEX_CHARS" ]]; then
    echo "❌ ERROR: JWT_SECRET not set"
    echo "Generate with: openssl rand -hex 32"
    exit 1
fi

echo "✅ Configuration validated"

# ============================================================================
# DEPLOYMENT
# ============================================================================

echo ""
echo "🚀 Starting WippliFlow deployment to Azure Container Apps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Set default resource group
az configure --defaults group=$RESOURCE_GROUP location=$LOCATION

# ============================================================================
# STEP 1: Create Redis Cache
# ============================================================================

echo "📦 Step 1: Creating Redis Cache..."

# Check if Redis already exists
if az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "ℹ️  Redis cache '$REDIS_NAME' already exists, skipping..."
else
    echo "Creating Redis cache '$REDIS_NAME'..."
    az redis create \
        --name $REDIS_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku $REDIS_SKU \
        --vm-size $REDIS_VM_SIZE \
        --enable-non-ssl-port false \
        --minimum-tls-version 1.2

    echo "✅ Redis cache created"
fi

# Get Redis connection details
echo "Getting Redis connection details..."
REDIS_HOST=$(az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query hostName -o tsv)
REDIS_SSL_PORT=$(az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query sslPort -o tsv)
REDIS_KEY=$(az redis list-keys --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query primaryKey -o tsv)

echo "✅ Redis: $REDIS_HOST:$REDIS_SSL_PORT"

# ============================================================================
# STEP 2: Create PostgreSQL Database
# ============================================================================

echo ""
echo "🗄️  Step 2: Creating PostgreSQL database..."

# Check if database exists
if az postgres flexible-server db show \
    --resource-group $RESOURCE_GROUP \
    --server-name $POSTGRES_SERVER \
    --database-name $POSTGRES_DATABASE &> /dev/null; then
    echo "ℹ️  Database '$POSTGRES_DATABASE' already exists, skipping..."
else
    echo "Creating database '$POSTGRES_DATABASE'..."
    az postgres flexible-server db create \
        --resource-group $RESOURCE_GROUP \
        --server-name $POSTGRES_SERVER \
        --database-name $POSTGRES_DATABASE

    echo "✅ Database created"
fi

# Get PostgreSQL host
POSTGRES_HOST=$(az postgres flexible-server show \
    --resource-group $RESOURCE_GROUP \
    --name $POSTGRES_SERVER \
    --query fullyQualifiedDomainName -o tsv)

echo "✅ PostgreSQL: $POSTGRES_HOST"

# Note: You need to create the user manually via Azure CLI or psql
echo ""
echo "⚠️  IMPORTANT: Create PostgreSQL user manually:"
echo "   Run this command to connect to PostgreSQL:"
echo "   az postgres flexible-server execute \\"
echo "     --name $POSTGRES_SERVER \\"
echo "     --admin-user <admin-username> \\"
echo "     --admin-password <admin-password> \\"
echo "     --database-name postgres \\"
echo "     --querytext \"CREATE USER $POSTGRES_USERNAME WITH PASSWORD '$POSTGRES_PASSWORD'; GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DATABASE TO $POSTGRES_USERNAME;\""
echo ""

# ============================================================================
# STEP 3: Deploy Container App
# ============================================================================

echo ""
echo "🐳 Step 3: Deploying WippliFlow Container App..."

# Check if Container App exists
if az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "ℹ️  Container App '$CONTAINER_APP_NAME' already exists, updating..."
    UPDATE_MODE=true
else
    echo "Creating Container App '$CONTAINER_APP_NAME'..."
    UPDATE_MODE=false
fi

# Create or update Container App
if [ "$UPDATE_MODE" = false ]; then
    az containerapp create \
        --name $CONTAINER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --environment $CONTAINER_APP_ENV \
        --image $CONTAINER_IMAGE \
        --target-port 80 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 3 \
        --cpu 1.0 \
        --memory 2.0Gi \
        --secrets \
            postgres-password="$POSTGRES_PASSWORD" \
            redis-password="$REDIS_KEY" \
            encryption-key="$ENCRYPTION_KEY" \
            jwt-secret="$JWT_SECRET" \
        --env-vars \
            AP_EXECUTION_MODE=UNSANDBOXED \
            AP_ENVIRONMENT=production \
            AP_ENGINE_EXECUTABLE_PATH=dist/packages/engine/main.js \
            AP_POSTGRES_DATABASE=$POSTGRES_DATABASE \
            AP_POSTGRES_HOST=$POSTGRES_HOST \
            AP_POSTGRES_PORT=5432 \
            AP_POSTGRES_USERNAME=$POSTGRES_USERNAME \
            AP_POSTGRES_PASSWORD=secretref:postgres-password \
            AP_POSTGRES_SSL_CA=true \
            AP_REDIS_HOST=$REDIS_HOST \
            AP_REDIS_PORT=$REDIS_SSL_PORT \
            AP_REDIS_PASSWORD=secretref:redis-password \
            AP_REDIS_USE_SSL=true \
            AP_ENCRYPTION_KEY=secretref:encryption-key \
            AP_JWT_SECRET=secretref:jwt-secret \
            AP_FRONTEND_URL=$FRONTEND_URL \
            AP_WEBHOOK_TIMEOUT_SECONDS=30 \
            AP_TRIGGER_DEFAULT_POLL_INTERVAL=5 \
            AP_FLOW_TIMEOUT_SECONDS=600 \
            AP_TELEMETRY_ENABLED=false \
            AP_SIGN_UP_ENABLED=false \
            AP_TEMPLATES_SOURCE_URL=https://cloud.activepieces.com/api/v1/flow-templates
else
    az containerapp update \
        --name $CONTAINER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --image $CONTAINER_IMAGE
fi

# Get Container App URL
CONTAINER_APP_URL=$(az containerapp show \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn -o tsv)

echo "✅ Container App deployed"

# ============================================================================
# DEPLOYMENT COMPLETE
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 WippliFlow Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Deployment Summary:"
echo "   • Container App: $CONTAINER_APP_NAME"
echo "   • URL: https://$CONTAINER_APP_URL"
echo "   • Redis: $REDIS_HOST"
echo "   • PostgreSQL: $POSTGRES_HOST"
echo "   • Database: $POSTGRES_DATABASE"
echo ""
echo "🔗 Next Steps:"
echo "   1. Configure custom domain: $FRONTEND_URL"
echo "   2. Create first admin user (first login)"
echo "   3. Configure Wippli integration (see INTEGRATION.md)"
echo "   4. Create workflow templates"
echo ""
echo "📚 Documentation:"
echo "   • Integration Guide: azure/INTEGRATION.md"
echo "   • Environment Variables: azure/ENVIRONMENT_VARIABLES.md"
echo "   • Custom Domain Setup: azure/CUSTOM_DOMAIN.md"
echo ""
echo "⚠️  Remember to:"
echo "   • Store secrets securely (Azure Key Vault recommended)"
echo "   • Set up monitoring and alerts"
echo "   • Configure backup strategy"
echo ""
