# WippliFlow - Deployment & Integration Guide

**White-Labeled Workflow Automation for Wippli**

This is a fork of [Activepieces](https://github.com/activepieces/activepieces) for Wippli's dedicated use.

---

## 🚨 Critical Rules

1. **DO NOT MODIFY ACTIVEPIECES CODE** - Use upstream as-is
2. **ALL Wippli integration in `wippli-monorepo`** - Not this repo
3. **Standalone deployment** - Runs independently in Azure
4. **API integration only** - REST API communication

---

## Quick Start

### 1. Deploy WippliFlow

```bash
cd WippliFlow

# Configure deployment (edit azure/deploy.sh first)
# - Set secure passwords
# - Generate encryption keys: openssl rand -hex 32

# Deploy to Azure
chmod +x azure/deploy.sh
./azure/deploy.sh
```

**Deploys to**:
- Resource Group: `wippliflow-au-rg`
- Location: Australia East
- URL: `https://flow.wippli.ai`
- Cost: ~$92-137/month

### 2. First Login

1. Navigate to deployed URL
2. First user becomes admin
3. Disable sign-ups (already configured)
4. Generate API key for Wippli

### 3. Integrate with Wippli

**See**: `azure/INTEGRATION.md` for complete dev team guide

**Summary**:
- Add `WippliflowClientService` in `wippli-monorepo/apps/store-api`
- Add management UI in `wippli-monorepo/apps/admin-client`
- Add marketplace in `wippli-monorepo/apps/main-client`
- Add webhooks in `wippli-monorepo/apps/main-api`

---

## Documentation

| File | Purpose |
|------|---------|
| `azure/deploy.sh` | Azure deployment script |
| `azure/INTEGRATION.md` | Complete integration guide for devs |
| `azure/ENVIRONMENT_VARIABLES.md` | Configuration reference |
| `azure/CUSTOM_DOMAIN.md` | Domain setup |

---

## Architecture

```
Wippli Platform (wippli-monorepo)
    │
    │ REST API
    ▼
WippliFlow (THIS REPO)
    │
    ├─ Container App (wippliflow)
    ├─ PostgreSQL (wippliflow-pg-server)
    └─ Redis (wippliflow-redis)
```

---

## Key Points

- **Upstream**: Stay synced with Activepieces
- **No modifications**: Keep codebase clean
- **Integration**: All in wippli-monorepo
- **Deployment**: Azure Container Apps
- **Authentication**: API key-based
- **Multi-tenant**: User projects isolated

---

## Support

- **Deployment**: Review `azure/deploy.sh` and logs
- **Integration**: See `azure/INTEGRATION.md`
- **Activepieces**: https://www.activepieces.com/docs

---

**Maintained by**: Wippli Team
**Based on**: Activepieces (MIT License)
**Deployed**: Azure Container Apps (Australia East)
