#!/bin/bash
# WippliFlow - Azure Container Apps Deployment Script
# Deploys to: wippliflow-au-rg (Australia East)
# DO NOT RUN WITHOUT CONFIGURING VARIABLES BELOW

set -e

# ============================================================================
# CONFIGURATION - MODIFY THESE VALUES BEFORE RUNNING
# ============================================================================

RESOURCE_GROUP="wippliflow-au-rg"
LOCATION="australiaeast"
CONTAINER_APP_ENV="wippliflow-env"
CONTAINER_APP_NAME="wippliflow"

# Database Configuration (new PostgreSQL server)
POSTGRES_SERVER="wippliflow-pg-server"
POSTGRES_ADMIN_USER="wippliflow_admin"
POSTGRES_ADMIN_PASSWORD="CHANGE_ME_ADMIN_PASSWORD"  # Generate secure password
POSTGRES_DATABASE="wippliflow_production"
POSTGRES_APP_USER="wippliflow_user"
POSTGRES_APP_PASSWORD="CHANGE_ME_APP_PASSWORD"  # Generate secure password

# Redis Configuration
REDIS_NAME="wippliflow-redis"
REDIS_SKU="Basic"
REDIS_VM_SIZE="c0"

# WippliFlow Configuration
CONTAINER_IMAGE="ghcr.io/activepieces/activepieces:latest"
FRONTEND_URL="https://flow.wippli.ai"
WEBHOOK_URL="https://api.wippli.ai/wippliflow/webhook"

# Generate these with: openssl rand -hex 32
ENCRYPTION_KEY=""  # 64 characters (32 bytes hex)
JWT_SECRET=""      # 64 characters (32 bytes hex)
API_KEY=""         # Optional admin API key

# ============================================================================
# VALIDATION
# ============================================================================

echo "🔍 Validating configuration..."

if [[ -z "$ENCRYPTION_KEY" ]]; then
    echo "❌ ERROR: ENCRYPTION_KEY not set"
    echo "Generate with: openssl rand -hex 32"
    exit 1
fi

if [[ -z "$JWT_SECRET" ]]; then
    echo "❌ ERROR: JWT_SECRET not set"
    echo "Generate with: openssl rand -hex 32"
    exit 1
fi

if [[ "$POSTGRES_ADMIN_PASSWORD" == "CHANGE_ME_ADMIN_PASSWORD" ]]; then
    echo "❌ ERROR: POSTGRES_ADMIN_PASSWORD not set"
    exit 1
fi

if [[ "$POSTGRES_APP_PASSWORD" == "CHANGE_ME_APP_PASSWORD" ]]; then
    echo "❌ ERROR: POSTGRES_APP_PASSWORD not set"
    exit 1
fi

echo "✅ Configuration validated"

# ============================================================================
# DEPLOYMENT START
# ============================================================================

echo ""
echo "🚀 Starting WippliFlow Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Container App: $CONTAINER_APP_NAME"
echo "Frontend URL: $FRONTEND_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# STEP 1: Create Resource Group
# ============================================================================

echo "📦 Step 1: Creating Resource Group..."

if az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo "ℹ️  Resource group '$RESOURCE_GROUP' already exists"
else
    echo "Creating resource group '$RESOURCE_GROUP'..."
    az group create \
        --name $RESOURCE_GROUP \
        --location $LOCATION \
        --tags \
            environment=production \
            product=wippliflow \
            managedBy=wippli-team

    echo "✅ Resource group created"
fi

# Set defaults
az configure --defaults group=$RESOURCE_GROUP location=$LOCATION

# ============================================================================
# STEP 2: Create Container Apps Environment
# ============================================================================

echo ""
echo "🏗️  Step 2: Creating Container Apps Environment..."

if az containerapp env show --name $CONTAINER_APP_ENV --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "ℹ️  Container Apps Environment '$CONTAINER_APP_ENV' already exists"
else
    echo "Creating Container Apps Environment '$CONTAINER_APP_ENV'..."
    az containerapp env create \
        --name $CONTAINER_APP_ENV \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION

    echo "✅ Container Apps Environment created"
fi

# ============================================================================
# STEP 3: Create PostgreSQL Flexible Server
# ============================================================================

echo ""
echo "🗄️  Step 3: Creating PostgreSQL Flexible Server..."

if az postgres flexible-server show --name $POSTGRES_SERVER --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "ℹ️  PostgreSQL server '$POSTGRES_SERVER' already exists"
else
    echo "Creating PostgreSQL server '$POSTGRES_SERVER'..."
    az postgres flexible-server create \
        --name $POSTGRES_SERVER \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --admin-user $POSTGRES_ADMIN_USER \
        --admin-password "$POSTGRES_ADMIN_PASSWORD" \
        --sku-name Standard_B1ms \
        --tier Burstable \
        --version 16 \
        --storage-size 32 \
        --public-access 0.0.0.0-255.255.255.255 \
        --yes

    echo "✅ PostgreSQL server created"
fi

# Get PostgreSQL host
POSTGRES_HOST=$(az postgres flexible-server show \
    --resource-group $RESOURCE_GROUP \
    --name $POSTGRES_SERVER \
    --query fullyQualifiedDomainName -o tsv)

echo "✅ PostgreSQL: $POSTGRES_HOST"

# Create database
echo "Creating database '$POSTGRES_DATABASE'..."
if az postgres flexible-server db show \
    --resource-group $RESOURCE_GROUP \
    --server-name $POSTGRES_SERVER \
    --database-name $POSTGRES_DATABASE &> /dev/null; then
    echo "ℹ️  Database already exists"
else
    az postgres flexible-server db create \
        --resource-group $RESOURCE_GROUP \
        --server-name $POSTGRES_SERVER \
        --database-name $POSTGRES_DATABASE

    echo "✅ Database created"
fi

# Create application user
echo "Creating application user '$POSTGRES_APP_USER'..."
az postgres flexible-server execute \
    --name $POSTGRES_SERVER \
    --admin-user $POSTGRES_ADMIN_USER \
    --admin-password "$POSTGRES_ADMIN_PASSWORD" \
    --database-name postgres \
    --querytext "CREATE USER $POSTGRES_APP_USER WITH PASSWORD '$POSTGRES_APP_PASSWORD';" \
    2>/dev/null || echo "ℹ️  User may already exist"

az postgres flexible-server execute \
    --name $POSTGRES_SERVER \
    --admin-user $POSTGRES_ADMIN_USER \
    --admin-password "$POSTGRES_ADMIN_PASSWORD" \
    --database-name $POSTGRES_DATABASE \
    --querytext "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DATABASE TO $POSTGRES_APP_USER;" \
    2>/dev/null || echo "ℹ️  Privileges may already be granted"

echo "✅ Application user configured"

# ============================================================================
# STEP 4: Create Redis Cache
# ============================================================================

echo ""
echo "📦 Step 4: Creating Redis Cache..."

if az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "ℹ️  Redis cache '$REDIS_NAME' already exists"
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
REDIS_HOST=$(az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query hostName -o tsv)
REDIS_SSL_PORT=$(az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query sslPort -o tsv)
REDIS_KEY=$(az redis list-keys --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query primaryKey -o tsv)

echo "✅ Redis: $REDIS_HOST:$REDIS_SSL_PORT"

# ============================================================================
# STEP 5: Deploy WippliFlow Container App
# ============================================================================

echo ""
echo "🐳 Step 5: Deploying WippliFlow Container App..."

if az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "ℹ️  Container App '$CONTAINER_APP_NAME' already exists, updating..."

    az containerapp update \
        --name $CONTAINER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --image $CONTAINER_IMAGE

    echo "✅ Container App updated"
else
    echo "Creating Container App '$CONTAINER_APP_NAME'..."

    # Build env vars string for API key if provided
    API_KEY_ENV=""
    if [[ -n "$API_KEY" ]]; then
        API_KEY_ENV="AP_API_KEY=secretref:api-key"
    fi

    az containerapp create \
        --name $CONTAINER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --environment $CONTAINER_APP_ENV \
        --image $CONTAINER_IMAGE \
        --target-port 80 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 5 \
        --cpu 1.0 \
        --memory 2.0Gi \
        --secrets \
            postgres-password="$POSTGRES_APP_PASSWORD" \
            redis-password="$REDIS_KEY" \
            encryption-key="$ENCRYPTION_KEY" \
            jwt-secret="$JWT_SECRET" \
            ${API_KEY:+api-key="$API_KEY"} \
        --env-vars \
            AP_EXECUTION_MODE=UNSANDBOXED \
            AP_ENVIRONMENT=production \
            AP_ENGINE_EXECUTABLE_PATH=dist/packages/engine/main.js \
            AP_POSTGRES_DATABASE=$POSTGRES_DATABASE \
            AP_POSTGRES_HOST=$POSTGRES_HOST \
            AP_POSTGRES_PORT=5432 \
            AP_POSTGRES_USERNAME=$POSTGRES_APP_USER \
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
            AP_TEMPLATES_SOURCE_URL=https://cloud.activepieces.com/api/v1/flow-templates \
            ${API_KEY_ENV}

    echo "✅ Container App created"
fi

# Get Container App URL
CONTAINER_APP_URL=$(az containerapp show \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn -o tsv)

# ============================================================================
# DEPLOYMENT COMPLETE
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 WippliFlow Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Deployment Summary:"
echo "   • Resource Group: $RESOURCE_GROUP"
echo "   • Location: $LOCATION"
echo "   • Container App: $CONTAINER_APP_NAME"
echo "   • URL: https://$CONTAINER_APP_URL"
echo "   • Redis: $REDIS_HOST"
echo "   • PostgreSQL: $POSTGRES_HOST"
echo "   • Database: $POSTGRES_DATABASE"
echo ""
echo "🔗 Access WippliFlow:"
echo "   • Direct URL: https://$CONTAINER_APP_URL"
echo "   • Custom Domain: $FRONTEND_URL (configure DNS)"
echo ""
echo "👤 First Login:"
echo "   1. Navigate to: https://$CONTAINER_APP_URL"
echo "   2. First user becomes admin automatically"
echo "   3. Sign-ups are disabled (AP_SIGN_UP_ENABLED=false)"
echo "   4. Create users via Wippli integration or admin panel"
echo ""
echo "🔗 Next Steps:"
echo "   1. Configure custom domain: $FRONTEND_URL"
echo "   2. Test the deployment"
echo "   3. Review integration docs: azure/INTEGRATION.md"
echo "   4. Create workflow templates"
echo ""
echo "📚 Documentation:"
echo "   • Integration Guide: azure/INTEGRATION.md"
echo "   • Environment Variables: azure/ENVIRONMENT_VARIABLES.md"
echo "   • Custom Domain Setup: azure/CUSTOM_DOMAIN.md"
echo ""
echo "💰 Estimated Monthly Cost:"
echo "   • Container Apps Environment: ~$0 (consumption)"
echo "   • WippliFlow Container App: ~$60-100"
echo "   • PostgreSQL B1ms: ~$15-20"
echo "   • Redis Basic C0: ~$17"
echo "   • Total: ~$92-137/month"
echo ""
echo "⚠️  Security Reminders:"
echo "   • Store passwords in Azure Key Vault"
echo "   • Rotate secrets regularly"
echo "   • Set up monitoring and alerts"
echo "   • Configure backup strategy"
echo "   • Review PostgreSQL firewall rules"
echo ""
