# WippliFlow Deployment Checklist

**Target**: Azure Container Apps (wippliflow-au-rg, Australia East)
**Status**: Ready for deployment

---

## Pre-Deployment Checklist

### ✅ Repository Setup

- [x] Forked from Activepieces
- [x] Deployment scripts created
- [x] Documentation complete
- [x] .gitignore configured for secrets
- [x] All changes committed to GitHub

### ✅ Secrets Generated

Secrets have been generated and saved in `.env.deployment` (not committed):

- [x] ENCRYPTION_KEY (64 chars hex)
- [x] JWT_SECRET (64 chars hex)
- [x] POSTGRES_ADMIN_PASSWORD (secure)
- [x] POSTGRES_APP_PASSWORD (secure)

### 📋 Azure Prerequisites

- [ ] Azure CLI installed and authenticated
- [ ] Correct subscription selected
- [ ] Permissions to create resources in Australia East
- [ ] Reviewed estimated costs (~$92-137/month)

---

## Deployment Steps

### Step 1: Verify Azure Authentication

```bash
# Check Azure login
az account show

# If needed, login
az login

# Set correct subscription if you have multiple
az account set --subscription "your-subscription-name"
```

**Checklist**:
- [ ] Logged into Azure CLI
- [ ] Correct subscription selected
- [ ] Permissions verified

### Step 2: Review Configuration

```bash
cd /Users/wippliair/Development/WippliFlow

# Review deployment script
cat azure/deploy.sh

# Check secrets file exists
ls -la .env.deployment
```

**Checklist**:
- [ ] Deployment script reviewed
- [ ] Secrets file exists
- [ ] Configuration looks correct

### Step 3: Configure Deployment Script

Option A: Use .env.deployment file (recommended):

```bash
# Source the secrets
source .env.deployment

# Verify variables loaded
echo $ENCRYPTION_KEY | head -c 20 && echo "..."
```

Option B: Edit deploy.sh directly:

```bash
# Edit azure/deploy.sh
# Replace these values:
# - POSTGRES_ADMIN_PASSWORD
# - POSTGRES_APP_PASSWORD
# - ENCRYPTION_KEY
# - JWT_SECRET
```

**Checklist**:
- [ ] Secrets configured in script
- [ ] Passwords are secure (min 16 chars)
- [ ] Encryption keys are 64 hex chars

### Step 4: Run Deployment

```bash
# Make script executable
chmod +x azure/deploy.sh

# Run deployment
./azure/deploy.sh

# Expected duration: 15-20 minutes
```

**What to watch for**:
- Resource group creation
- Container Apps Environment creation
- PostgreSQL server creation (~5 min)
- Redis cache creation (~3 min)
- Container App deployment (~5 min)

**Checklist**:
- [ ] Script started successfully
- [ ] No errors during execution
- [ ] All resources created
- [ ] Container App URL provided

### Step 5: Verify Deployment

```bash
# Get Container App details
az containerapp show \
  --name wippliflow \
  --resource-group wippliflow-au-rg \
  --query "{fqdn:properties.configuration.ingress.fqdn,status:properties.runningStatus}" \
  --output table

# View logs
az containerapp logs show \
  --name wippliflow \
  --resource-group wippliflow-au-rg \
  --tail 50
```

**Checklist**:
- [ ] Container App is running
- [ ] Ingress FQDN is accessible
- [ ] Logs show no errors
- [ ] Can access URL in browser

---

## Post-Deployment Steps

### Step 1: Access WippliFlow

1. Navigate to Container App URL
2. You should see Activepieces login/signup page

**Checklist**:
- [ ] URL loads successfully
- [ ] Login page displays
- [ ] No errors in browser console

### Step 2: Create Admin Account

1. **IMPORTANT**: First user becomes admin
2. Click "Sign Up" (even though AP_SIGN_UP_ENABLED=false, first user works)
3. Enter details:
   - Email: `admin@wippli.ai` (or your preferred admin email)
   - Password: Secure password
   - First Name: Admin
   - Last Name: Wippli
4. Verify email (if required)

**Checklist**:
- [ ] Admin account created
- [ ] Can login successfully
- [ ] Admin panel accessible

### Step 3: Disable Further Sign-ups

Already configured in deployment:
```bash
AP_SIGN_UP_ENABLED=false
```

**Checklist**:
- [ ] Verify sign-up is disabled for other users
- [ ] Only admin can create users

### Step 4: Generate API Key

1. Login as admin
2. Navigate to: Settings → API Keys
3. Click "Generate API Key"
4. Copy and save securely
5. Store in password manager

**Checklist**:
- [ ] API key generated
- [ ] API key saved securely
- [ ] API key format: `ap_xxxxxxxxxxxx`

### Step 5: Test API Access

```bash
# Replace with your actual API key and URL
API_KEY="your-api-key-here"
URL="https://your-container-app-url.australiaeast.azurecontainerapps.io"

# Test API
curl -X GET "$URL/api/v1/users/me" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json"
```

**Expected response**: User details in JSON

**Checklist**:
- [ ] API responds successfully
- [ ] Returns valid user data
- [ ] No authentication errors

---

## Validation Checklist

### Infrastructure

- [ ] Resource group `wippliflow-au-rg` exists
- [ ] Container Apps Environment `wippliflow-env` running
- [ ] Container App `wippliflow` running
- [ ] PostgreSQL server `wippliflow-pg-server` healthy
- [ ] Redis cache `wippliflow-redis` running

### Application

- [ ] WippliFlow accessible via URL
- [ ] Admin account created and working
- [ ] API key generated
- [ ] API endpoints responding
- [ ] No errors in logs

### Security

- [ ] Sign-ups disabled
- [ ] Secrets stored securely (not in git)
- [ ] PostgreSQL firewall configured
- [ ] Redis SSL enabled
- [ ] HTTPS working

---

## Cost Verification

```bash
# Check current costs
az consumption usage list \
  --start-date $(date -u -d '1 day ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --end-date $(date -u '+%Y-%m-%dT%H:%M:%SZ') \
  | grep wippliflow
```

**Expected Monthly Costs**:
- Container Apps: ~$60-100
- PostgreSQL B1ms: ~$15-20
- Redis Basic: ~$17
- **Total**: ~$92-137/month

**Checklist**:
- [ ] Cost estimates reviewed
- [ ] Monitoring alerts set up (optional)
- [ ] Budget alerts configured (optional)

---

## Documentation

### Save Deployment Details

Create a file: `deployment-info.txt` (DO NOT COMMIT)

```
Deployment Date: [DATE]
Resource Group: wippliflow-au-rg
Location: Australia East

URLs:
- Container App: https://[your-fqdn].australiaeast.azurecontainerapps.io
- Custom Domain: https://flow.wippli.ai (to be configured)

Admin Account:
- Email: [your-admin-email]
- Password: [stored in password manager]

API Key: [stored in password manager]

PostgreSQL:
- Server: wippliflow-pg-server.postgres.database.azure.com
- Database: wippliflow_production
- Admin User: wippliflow_admin
- App User: wippliflow_user

Redis:
- Host: wippliflow-redis.redis.cache.windows.net
- Port: 6380 (SSL)
```

**Checklist**:
- [ ] Deployment details documented
- [ ] Stored securely (not in git)
- [ ] Shared with relevant team members

---

## Troubleshooting

### Common Issues

**Issue**: Container App not starting

```bash
# Check logs
az containerapp logs show --name wippliflow --resource-group wippliflow-au-rg --tail 100

# Common causes:
# - Database connection failed
# - Invalid encryption key
# - Image pull error
```

**Issue**: Cannot access URL

```bash
# Check ingress configuration
az containerapp ingress show --name wippliflow --resource-group wippliflow-au-rg

# Check if app is running
az containerapp show --name wippliflow --resource-group wippliflow-au-rg \
  --query properties.runningStatus
```

**Issue**: Database connection timeout

```bash
# Check PostgreSQL firewall
az postgres flexible-server firewall-rule list \
  --resource-group wippliflow-au-rg \
  --name wippliflow-pg-server

# Allow Azure services
az postgres flexible-server firewall-rule create \
  --resource-group wippliflow-au-rg \
  --name wippliflow-pg-server \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

---

## Rollback Plan

If deployment fails or issues occur:

```bash
# Delete resource group (removes everything)
az group delete --name wippliflow-au-rg --yes --no-wait

# Or delete specific resources
az containerapp delete --name wippliflow --resource-group wippliflow-au-rg
az postgres flexible-server delete --name wippliflow-pg-server --resource-group wippliflow-au-rg
az redis delete --name wippliflow-redis --resource-group wippliflow-au-rg
```

**Checklist**:
- [ ] Backup plan understood
- [ ] Know how to rollback if needed

---

## Next Steps (Optional)

### Configure Custom Domain

```bash
# Add custom domain
az containerapp hostname add \
  --name wippliflow \
  --resource-group wippliflow-au-rg \
  --hostname flow.wippli.ai

# Bind certificate (requires certificate)
az containerapp hostname bind \
  --name wippliflow \
  --resource-group wippliflow-au-rg \
  --hostname flow.wippli.ai \
  --certificate [certificate-id]
```

### Set Up Monitoring

```bash
# Enable Application Insights (optional)
az monitor app-insights component create \
  --app wippliflow-insights \
  --location australiaeast \
  --resource-group wippliflow-au-rg
```

### Create Backups

```bash
# PostgreSQL automatic backups are enabled by default
# Verify backup retention
az postgres flexible-server show \
  --resource-group wippliflow-au-rg \
  --name wippliflow-pg-server \
  --query backup
```

---

## Final Checklist

- [ ] All pre-deployment steps completed
- [ ] Deployment executed successfully
- [ ] Post-deployment steps completed
- [ ] Validation passed
- [ ] Documentation updated
- [ ] Secrets stored securely
- [ ] Team notified (if applicable)
- [ ] Monitoring configured (optional)

---

## Success Criteria

✅ **Deployment is successful when**:

1. Container App is running and accessible
2. Admin account created and can login
3. API key generated and working
4. No errors in logs
5. Database connected successfully
6. Redis connected successfully
7. All resources healthy in Azure

---

**Status**: Ready for deployment
**Estimated Time**: 30-45 minutes total
**Next Action**: Follow steps above when ready to deploy

---

**Document Version**: 1.0
**Created**: October 27, 2025
**For**: WippliFlow standalone deployment to Azure
