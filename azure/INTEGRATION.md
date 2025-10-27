# WippliFlow ↔ Wippli Integration Guide

**For: Wippli Development Team**
**Date**: October 27, 2025
**Status**: Ready for Implementation

---

## ⚠️ CRITICAL RULES

1. **DO NOT MODIFY WippliFlow repository** - Use it as-is (forked from Activepieces)
2. **ALL integration code goes in Wippli monorepo** - `/Users/wippliair/Development/wippli-monorepo`
3. **WippliFlow runs standalone** - Separate Container App in `wippliflow-au-rg`
4. **Communication via REST API only** - HTTP requests with API key authentication
5. **EXAMINE Wippli code to understand structure** - But DO NOT modify it

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Wippli Platform                      │
│            (wippli-monorepo - Australia East)           │
│                                                         │
│  Integration Points (ADD CODE HERE):                    │
│  ├─ admin-client/  → WippliFlow management UI          │
│  ├─ main-client/   → Workflow marketplace UI           │
│  ├─ store-api/     → WippliflowClientService (NEW)     │
│  └─ main-api/      → Webhook handlers (NEW)            │
└─────────────────────────────────────────────────────────┘
                          │
                          │ REST API (HTTPS)
                          │ Authorization: Bearer {api_key}
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  WippliFlow Platform                    │
│         (Standalone - wippliflow-au-rg)                 │
│              ⚠️ DO NOT MODIFY THIS CODE                  │
│                                                         │
│  URL: https://flow.wippli.ai                           │
│  API: https://flow.wippli.ai/api/v1/                   │
│                                                         │
│  Available Endpoints:                                   │
│  • POST   /api/v1/users                                │
│  • GET    /api/v1/users/me                             │
│  • POST   /api/v1/projects                             │
│  • GET    /api/v1/projects                             │
│  • POST   /api/v1/flows                                │
│  • GET    /api/v1/flows?projectId={id}                 │
│  • PUT    /api/v1/flows/{id}                           │
│  • POST   /api/v1/flows/{id}/execute                   │
│  • GET    /api/v1/flow-templates                       │
│  • Webhooks: /webhooks/{webhookId}                     │
└─────────────────────────────────────────────────────────┘
```

---

## Integration Implementation Plan

### Phase 1: Backend Integration (store-api)

**Location**: `/Users/wippliair/Development/wippli-monorepo/apps/store-api/src/`

#### 1.1 Create WippliFlow Client Module

**File**: `src/wippliflow-client/wippliflow-client.module.ts`

```typescript
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { WippliflowClientService } from './wippliflow-client.service';

@Module({
  imports: [
    HttpModule.register({
      baseURL: process.env.WIPPLIFLOW_API_URL || 'https://flow.wippli.ai/api/v1',
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    }),
  ],
  providers: [WippliflowClientService],
  exports: [WippliflowClientService],
})
export class WippliflowClientModule {}
```

**File**: `src/wippliflow-client/wippliflow-client.service.ts`

```typescript
import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { AxiosError } from 'axios';

@Injectable()
export class WippliflowClientService {
  constructor(private readonly httpService: HttpService) {}

  /**
   * Create a new user in WippliFlow
   * @param email User email
   * @param password User password
   * @param firstName First name
   * @param lastName Last name
   * @returns User object with id
   */
  async createUser(
    email: string,
    password: string,
    firstName: string,
    lastName: string,
    apiKey: string,
  ): Promise<any> {
    try {
      return await firstValueFrom(
        this.httpService.post(
          '/users',
          {
            email,
            password,
            firstName,
            lastName,
            trackEvents: false,
            newsLetter: false,
          },
          {
            headers: { Authorization: `Bearer ${apiKey}` },
          },
        ).pipe(
          map((response) => response.data),
          catchError(this.handleError),
        ),
      );
    } catch (error) {
      throw new HttpException(
        'Failed to create WippliFlow user',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Create a project for a user
   * @param displayName Project name
   * @param apiKey WippliFlow API key
   * @returns Project object with id
   */
  async createProject(
    displayName: string,
    apiKey: string,
  ): Promise<{ id: string; displayName: string }> {
    try {
      return await firstValueFrom(
        this.httpService.post(
          '/projects',
          { displayName },
          {
            headers: { Authorization: `Bearer ${apiKey}` },
          },
        ).pipe(
          map((response) => response.data),
          catchError(this.handleError),
        ),
      );
    } catch (error) {
      throw new HttpException(
        'Failed to create WippliFlow project',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * List flows in a project
   * @param projectId Project ID
   * @param apiKey WippliFlow API key
   * @returns Array of flows
   */
  async listFlows(projectId: string, apiKey: string): Promise<any[]> {
    try {
      return await firstValueFrom(
        this.httpService.get('/flows', {
          params: { projectId, limit: 100 },
          headers: { Authorization: `Bearer ${apiKey}` },
        }).pipe(
          map((response) => response.data.data || []),
          catchError(this.handleError),
        ),
      );
    } catch (error) {
      throw new HttpException(
        'Failed to list WippliFlow flows',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Execute a flow
   * @param flowId Flow ID
   * @param payload Execution payload
   * @param apiKey WippliFlow API key
   * @returns Execution result
   */
  async executeFlow(
    flowId: string,
    payload: any,
    apiKey: string,
  ): Promise<any> {
    try {
      return await firstValueFrom(
        this.httpService.post(
          `/flows/${flowId}/execute`,
          { payload },
          {
            headers: { Authorization: `Bearer ${apiKey}` },
          },
        ).pipe(
          map((response) => response.data),
          catchError(this.handleError),
        ),
      );
    } catch (error) {
      throw new HttpException(
        'Failed to execute WippliFlow flow',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get flow templates
   * @param apiKey WippliFlow API key
   * @returns Array of templates
   */
  async getFlowTemplates(apiKey: string): Promise<any[]> {
    try {
      return await firstValueFrom(
        this.httpService.get('/flow-templates', {
          headers: { Authorization: `Bearer ${apiKey}` },
        }).pipe(
          map((response) => response.data.data || []),
          catchError(this.handleError),
        ),
      );
    } catch (error) {
      throw new HttpException(
        'Failed to get flow templates',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Create flow from template
   * @param projectId Project ID
   * @param templateId Template ID
   * @param displayName Flow name
   * @param apiKey WippliFlow API key
   * @returns Created flow
   */
  async createFlowFromTemplate(
    projectId: string,
    templateId: string,
    displayName: string,
    apiKey: string,
  ): Promise<any> {
    try {
      return await firstValueFrom(
        this.httpService.post(
          '/flows',
          {
            projectId,
            displayName,
            templateId,
          },
          {
            headers: { Authorization: `Bearer ${apiKey}` },
          },
        ).pipe(
          map((response) => response.data),
          catchError(this.handleError),
        ),
      );
    } catch (error) {
      throw new HttpException(
        'Failed to create flow from template',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  private handleError(error: AxiosError): never {
    const status = error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR;
    const message = error.response?.data || 'WippliFlow API error';
    throw new HttpException(message, status);
  }
}
```

#### 1.2 Environment Variables

Add to `apps/store-api/.env`:

```bash
# WippliFlow Configuration
WIPPLIFLOW_API_URL=https://flow.wippli.ai/api/v1
WIPPLIFLOW_ADMIN_API_KEY=<generate_from_wippliflow_admin>
```

#### 1.3 Register Module

Add to `apps/store-api/src/app.module.ts`:

```typescript
import { WippliflowClientModule } from './wippliflow-client/wippliflow-client.module';

@Module({
  imports: [
    // ... existing imports
    WippliflowClientModule,
  ],
})
export class AppModule {}
```

---

### Phase 2: Database Schema (store-api)

**Location**: `apps/store-api/prisma/schema.prisma`

Add these models:

```prisma
model WippliflowUser {
  id                Int      @id @default(autoincrement())
  userId            Int      @unique // Wippli user ID
  wippliflowUserId  String   // WippliFlow user ID
  wippliflowProjectId String // WippliFlow project ID
  apiKey            String   // User's WippliFlow API key
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("wippliflow_users")
}

model WippliflowPackage {
  id          String   @id @default(uuid())
  name        String
  description String?
  price       Decimal  @db.Decimal(10, 2)
  category    String   // intelligence, automation, integration
  templateIds Json     // Array of template IDs
  features    Json     // Array of feature strings
  active      Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  subscriptions WippliflowSubscription[]

  @@map("wippliflow_packages")
}

model WippliflowSubscription {
  id         Int      @id @default(autoincrement())
  userId     Int
  packageId  String
  status     String   @default("active") // active, cancelled, expired
  startedAt  DateTime @default(now())
  expiresAt  DateTime?
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt

  user    User             @relation(fields: [userId], references: [id], onDelete: Cascade)
  package WippliflowPackage @relation(fields: [packageId], references: [id], onDelete: Cascade)

  @@unique([userId, packageId])
  @@map("wippliflow_subscriptions")
}
```

Run migration:

```bash
cd apps/store-api
npx prisma migrate dev --name add_wippliflow_tables
```

---

### Phase 3: Admin Centre Integration

**Location**: `apps/admin-client/src/pages/`

#### 3.1 Create WippliFlow Management Page

**File**: `apps/admin-client/src/pages/wippliflow/index.tsx`

```typescript
import React, { useState } from 'react';
import { Card, Button, Table, Badge, Group, Title } from '@mantine/core';
import { useQuery } from '@tanstack/react-query';
import axios from 'axios';

export default function WippliFlowManagement() {
  const { data: users, isLoading } = useQuery({
    queryKey: ['wippliflow-users'],
    queryFn: async () => {
      const response = await axios.get('/api/wippliflow/users');
      return response.data;
    },
  });

  const createUserProject = async (userId: number) => {
    try {
      await axios.post(`/api/wippliflow/users/${userId}/project`);
      // Refresh list
    } catch (error) {
      console.error('Failed to create project:', error);
    }
  };

  if (isLoading) return <div>Loading...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <Title order={1}>WippliFlow Management</Title>

      <Card mt="xl">
        <Title order={3}>WippliFlow Users</Title>

        <Table mt="md">
          <thead>
            <tr>
              <th>User</th>
              <th>Email</th>
              <th>WippliFlow Project</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {users?.map((user) => (
              <tr key={user.id}>
                <td>{user.name}</td>
                <td>{user.email}</td>
                <td>{user.wippliflowProjectId || 'Not created'}</td>
                <td>
                  <Badge color={user.wippliflowProjectId ? 'green' : 'gray'}>
                    {user.wippliflowProjectId ? 'Active' : 'Inactive'}
                  </Badge>
                </td>
                <td>
                  {!user.wippliflowProjectId && (
                    <Button
                      size="xs"
                      onClick={() => createUserProject(user.id)}
                    >
                      Create Project
                    </Button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      </Card>
    </div>
  );
}
```

Add route to admin navigation.

---

### Phase 4: Marketplace UI (main-client)

**Location**: `apps/main-client/src/pages/`

#### 4.1 Create Marketplace Page

**File**: `apps/main-client/src/pages/marketplace/index.tsx`

```typescript
import React from 'react';
import { Card, Grid, Button, Badge, Text, Title, Group } from '@mantine/core';
import { useQuery } from '@tanstack/react-query';
import axios from 'axios';

export default function WorkflowMarketplace() {
  const { data: packages, isLoading } = useQuery({
    queryKey: ['workflow-packages'],
    queryFn: async () => {
      const response = await axios.get('/api/workflow-packages');
      return response.data;
    },
  });

  const handlePurchase = async (packageId: string) => {
    try {
      const response = await axios.post('/api/workflow-packages/purchase', {
        packageId,
      });
      // Redirect to Stripe checkout
      window.location.href = response.data.checkoutUrl;
    } catch (error) {
      console.error('Purchase failed:', error);
    }
  };

  if (isLoading) return <div>Loading marketplace...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <Title order={1}>WippliFlow Marketplace</Title>
      <Text color="dimmed" mt="sm">
        Professional workflow automation packages
      </Text>

      <Grid gutter="md" mt="xl">
        {packages?.map((pkg) => (
          <Grid.Col key={pkg.id} span={4}>
            <Card shadow="sm" padding="lg" radius="md" withBorder>
              <Group position="apart" mb="xs">
                <Text weight={500} size="lg">
                  {pkg.name}
                </Text>
                <Badge color="blue" variant="light">
                  {pkg.category}
                </Badge>
              </Group>

              <Text size="sm" color="dimmed" mb="md">
                {pkg.description}
              </Text>

              <div>
                {pkg.features.slice(0, 3).map((feature, i) => (
                  <Text key={i} size="xs" color="dimmed">
                    ✓ {feature}
                  </Text>
                ))}
              </div>

              <Group position="apart" mt="md">
                <div>
                  <Text size="xl" weight={700} color="blue">
                    ${pkg.price}
                  </Text>
                  <Text size="xs" color="dimmed">
                    per month
                  </Text>
                </div>
                <Button onClick={() => handlePurchase(pkg.id)}>
                  Purchase
                </Button>
              </Group>
            </Card>
          </Grid.Col>
        ))}
      </Grid>
    </div>
  );
}
```

---

### Phase 5: Webhook Handler (main-api)

**Location**: `apps/main-api/src/modules/`

#### 5.1 Create WippliFlow Module

**File**: `apps/main-api/src/modules/wippliflow/wippliflow.module.ts`

```typescript
import { Module } from '@nestjs/common';
import { WippliflowController } from './wippliflow.controller';
import { WippliflowService } from './wippliflow.service';

@Module({
  controllers: [WippliflowController],
  providers: [WippliflowService],
  exports: [WippliflowService],
})
export class WippliflowModule {}
```

**File**: `apps/main-api/src/modules/wippliflow/wippliflow.controller.ts`

```typescript
import { Controller, Post, Body, Headers, HttpException, HttpStatus } from '@nestjs/common';
import { WippliflowService } from './wippliflow.service';

@Controller('wippliflow')
export class WippliflowController {
  constructor(private readonly wippliflowService: WippliflowService) {}

  /**
   * Webhook endpoint for WippliFlow to send results back to Wippli
   */
  @Post('webhook')
  async handleWebhook(
    @Body() payload: any,
    @Headers('x-webhook-signature') signature: string,
  ) {
    // Verify webhook signature
    const isValid = this.wippliflowService.verifyWebhookSignature(
      payload,
      signature,
    );

    if (!isValid) {
      throw new HttpException('Invalid signature', HttpStatus.UNAUTHORIZED);
    }

    // Process webhook payload
    return await this.wippliflowService.processWebhook(payload);
  }
}
```

---

## API Authentication

### Getting API Key from WippliFlow

1. **Admin Login**: First user to access WippliFlow becomes admin
2. **Navigate to**: Settings → API Keys
3. **Generate**: Create new API key
4. **Store**: Add to Wippli environment variables

```bash
# In Wippli store-api .env
WIPPLIFLOW_ADMIN_API_KEY=ap_xxxxxxxxxxxxxxxxxxxxx
```

### User API Keys

For per-user authentication:
- Each Wippli user gets their own WippliFlow API key
- Stored in `wippliflow_users.apiKey`
- Used for user-specific flow operations

---

## Testing the Integration

### 1. Test API Connection

```bash
# From Wippli server
curl -X GET https://flow.wippli.ai/api/v1/users/me \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### 2. Test User Creation

```typescript
// In Wippli code
const wippliflowService = // ... inject service

const result = await wippliflowService.createUser(
  'test@wippli.ai',
  'SecurePassword123!',
  'Test',
  'User',
  process.env.WIPPLIFLOW_ADMIN_API_KEY,
);

console.log('Created user:', result);
```

### 3. Test Project Creation

```typescript
const project = await wippliflowService.createProject(
  'Test User Workspace',
  userApiKey,
);

console.log('Created project:', project.id);
```

### 4. Test Flow Execution

```typescript
const result = await wippliflowService.executeFlow(
  'flow-id-here',
  { query: 'test query' },
  userApiKey,
);

console.log('Flow result:', result);
```

---

## Deployment Checklist

### Before Integration

- [ ] Deploy WippliFlow to `wippliflow-au-rg` (run `azure/deploy.sh`)
- [ ] Configure custom domain `flow.wippli.ai`
- [ ] Create first admin user in WippliFlow
- [ ] Generate admin API key
- [ ] Test WippliFlow is accessible

### Backend Integration

- [ ] Create `wippliflow-client` module in store-api
- [ ] Add environment variables
- [ ] Add Prisma models
- [ ] Run database migration
- [ ] Test API connection

### Frontend Integration

- [ ] Add WippliFlow management page to admin-client
- [ ] Add marketplace page to main-client
- [ ] Test user flows

### Webhook Integration

- [ ] Create webhook handler in main-api
- [ ] Configure webhook URL in WippliFlow
- [ ] Test webhook delivery

### Production Readiness

- [ ] Set up monitoring and alerts
- [ ] Configure backup strategy
- [ ] Review security settings
- [ ] Load testing
- [ ] Documentation complete

---

## Security Considerations

### API Key Storage

- **DO NOT** commit API keys to Git
- Use Azure Key Vault for production
- Rotate keys regularly
- Use separate keys for dev/staging/prod

### Webhook Security

- Verify webhook signatures
- Use HTTPS only
- Whitelist WippliFlow IP addresses
- Rate limit webhook endpoint

### User Isolation

- Each user has their own WippliFlow project
- Projects are isolated (multi-tenancy)
- Users cannot access other users' flows

---

## Cost Monitoring

### WippliFlow Infrastructure

- **Container App**: ~$60-100/month
- **PostgreSQL B1ms**: ~$15-20/month
- **Redis Basic**: ~$17/month
- **Total**: ~$92-137/month

### Scaling Costs

- Container App scales 1-5 replicas automatically
- At 500 users: ~$200-250/month
- At 1000 users: ~$350-400/month

---

## Support and Troubleshooting

### Common Issues

**Issue**: API connection timeout
- Check Container App is running
- Verify API key is correct
- Check firewall rules

**Issue**: User creation fails
- Check PostgreSQL connection
- Verify email is unique
- Check password complexity

**Issue**: Webhook not received
- Verify webhook URL is correct
- Check main-api is accessible
- Review webhook logs in WippliFlow

### Getting Help

- **WippliFlow Logs**: `az containerapp logs show --name wippliflow --resource-group wippliflow-au-rg`
- **Wippli Logs**: Check your application logs
- **Activepieces Docs**: https://www.activepieces.com/docs
- **GitHub Issues**: https://github.com/Wippli-Org/WippliFlow/issues

---

## Next Steps

1. Deploy WippliFlow using `azure/deploy.sh`
2. Test deployment and create admin user
3. Implement backend integration (Phase 1-2)
4. Implement frontend integration (Phase 3-4)
5. Test end-to-end user flow
6. Create first workflow packages
7. Launch to beta users

---

**Document Version**: 1.0
**Last Updated**: October 27, 2025
**Status**: Ready for Implementation
