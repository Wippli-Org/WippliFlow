# WippliFlow Azure Deployment

**Status**: Ready for deployment
**Target**: wippliflow-au-rg (Australia East)

---

## ⚠️ CRITICAL RULES

1. **DO NOT MODIFY WippliFlow/Activepieces CODE** - Deploy as-is
2. **DO NOT MODIFY Wippli monorepo CODE** - Keep separate
3. **Integration documentation is for REFERENCE ONLY** - For future implementation
4. **Deploy standalone** - WippliFlow runs independently

---

## What's In This Folder

### `deploy.sh` ✅ READY TO USE

Main deployment script that creates:
- Resource group: `wippliflow-au-rg`
- Container Apps Environment
- PostgreSQL server
- Redis cache
- Container App with Activepieces

**Configuration needed**:
- Set secure passwords
- Generate encryption keys
- Review settings

### `INTEGRATION.md` 📚 REFERENCE ONLY

**Purpose**: Documentation for future reference
**Status**: NOT IMPLEMENTED
**Action**: DO NOT implement now

This document shows how integration COULD work in the future.
Dev team can review when ready to connect Wippli to WippliFlow.

---

## How to Deploy

### Step 1: Configure

Edit `deploy.sh` and set:

```bash
# Generate these:
openssl rand -hex 32  # ENCRYPTION_KEY
openssl rand -hex 32  # JWT_SECRET

# Create secure passwords:
POSTGRES_ADMIN_PASSWORD="your-secure-password"
POSTGRES_APP_PASSWORD="your-secure-password"
```

### Step 2: Deploy

```bash
chmod +x deploy.sh
./deploy.sh
```

### Step 3: Access

1. Note the URL from deployment output
2. Navigate to URL
3. Create admin account
4. WippliFlow is ready!

---

## What Gets Deployed

```
wippliflow-au-rg (Australia East)
├── wippliflow-env (Container Apps Environment)
├── wippliflow (Container App - Activepieces)
├── wippliflow-pg-server (PostgreSQL)
└── wippliflow-redis (Redis Cache)
```

**Cost**: ~$92-137/month

---

## After Deployment

WippliFlow runs **standalone** - completely independent.

**No integration needed** - It works as a standalone Activepieces instance.

**Future integration** - Reference `INTEGRATION.md` when/if needed.

---

## Support

- **Deployment issues**: Check Azure Container App logs
- **Activepieces questions**: https://www.activepieces.com/docs
- **Configuration**: See deploy.sh comments

---

**Ready to deploy!**
