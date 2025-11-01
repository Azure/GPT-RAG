# GPT-RAG Frontend Architecture - Multi-Tenant Platform

## 🎯 Overview

This frontend has been redesigned as a **self-service, multi-tenant platform** where each business user can:
- **Configure** their own Azure environment
- **Deploy** their own GPT-RAG instance
- **Manage** their documents and data
- **Use** their personalized AI assistant

## 🏗️ Architecture Transformation

### Before (Single Deployment)
```
Frontend → Single Orchestrator → Single RAG System
```

### Now (Multi-Tenant Platform)
```
                     ┌─ User A's Azure ─┐
                     │  - Orchestrator  │
                     │  - AI Search     │
Frontend Platform ──┤  - Documents     │
                     │  - Cosmos DB     │
                     └──────────────────┘
                     
                     ┌─ User B's Azure ─┐
                     │  - Orchestrator  │
                     │  - AI Search     │
                     ├─  - Documents     │
                     │  - Cosmos DB     │
                     └──────────────────┘
```

## 📋 Key Components

### 1. Authentication System
**Location**: `src/contexts/AuthContext.tsx`

**Purpose**: Manage user sessions and environment switching

**Features**:
- User login/logout
- Session persistence (localStorage)
- Multiple environments per user
- Current environment tracking

```typescript
const { user, currentEnvironment, switchEnvironment } = useAuth();
```

### 2. Login Page
**Location**: `src/pages/LoginPage.tsx`

**Purpose**: User authentication entry point

**Features**:
- Modern, gradient design
- Azure branding
- Platform benefits showcase
- Responsive layout

### 3. Dashboard
**Location**: `src/pages/Dashboard.tsx`

**Purpose**: Main control center after login

**Features**:
- Environment overview
- Quick actions
- Chat interface toggle
- Resource monitoring
- Document management access

**States**:
- **No Environment**: Shows setup wizard CTA
- **Environment Exists**: Shows environment details and actions
- **Chat Mode**: Full chat interface

### 4. Setup Wizard
**Location**: `src/pages/SetupWizard.tsx`

**Purpose**: Guide users through Azure deployment configuration

**6-Step Flow**:
1. **Environment Details**: Name, type (dev/staging/prod)
2. **Azure Credentials**: Subscription ID, Tenant ID
3. **Location & Resources**: Region, resource group
4. **Feature Configuration**: Network isolation, agentic retrieval, Cosmos DB, VM
5. **AI Models**: Chat model (GPT-4o, GPT-3.5), Embedding model
6. **Review & Deploy**: Summary, cost estimate, deploy button

**Configurable Options** (from `main.parameters.json`):
- Network isolation (Zero Trust)
- Agentic retrieval
- Cosmos DB deployment
- Data Science VM
- Model selection
- Resource group creation

### 5. Updated API Service
**Location**: `src/services/api.ts`

**Purpose**: Handle multi-environment API calls

**Key Changes**:
- Dynamic endpoint configuration
- Environment-specific clients
- Deployment management APIs
- Document management APIs
- Metrics and monitoring APIs

```typescript
// Old: Single endpoint
await apiService.sendMessage(request);

// New: Environment-specific
await apiService.sendMessage(request, environment.orchestrator_endpoint);
```

## 🔐 Authentication Flow

```
1. User visits app
   ↓
2. Not authenticated → Show LoginPage
   ↓
3. User enters credentials
   ↓
4. AuthContext stores user data
   ↓
5. Redirect to Dashboard
   ↓
6. User manages environments
```

## 🚀 Deployment Configuration Flow

```
1. User clicks "Create Environment"
   ↓
2. SetupWizard opens (6-step process)
   ↓
3. User configures:
   - Environment name
   - Azure credentials
   - Location
   - Features (network isolation, etc.)
   - AI models
   ↓
4. Review configuration
   ↓
5. Click "Deploy Environment"
   ↓
6. Backend triggers Azure deployment
   ↓
7. Environment added to user's list
   ↓
8. User can start chatting once deployed
```

## 📊 Data Model

### User
```typescript
interface User {
  id: string;
  email: string;
  name: string;
  created_at: Date;
  environments: Environment[];
  current_environment_id?: string;
}
```

### Environment
```typescript
interface Environment {
  id: string;
  name: string;
  type: 'development' | 'staging' | 'production';
  azure_config: AzureConfiguration;
  deployment_status: DeploymentStatus;
  created_at: Date;
  updated_at: Date;
}
```

### Azure Configuration
```typescript
interface AzureConfiguration {
  // From main.parameters.json
  subscription_id: string;
  tenant_id: string;
  resource_group: string;
  location: string;
  environment_name: string;
  
  // Service endpoints (after deployment)
  orchestrator_endpoint?: string;
  frontend_endpoint?: string;
  data_ingest_endpoint?: string;
  
  // Deployment options
  network_isolation: boolean;
  enable_agentic_retrieval: boolean;
  deploy_cosmos_db: boolean;
  deploy_vm: boolean;
  
  // Models
  chat_model: ModelDeployment;
  embedding_model: ModelDeployment;
}
```

## 🔄 State Management

### Global State (AuthContext)
- `user`: Current logged-in user
- `currentEnvironment`: Selected environment
- `isAuthenticated`: Boolean
- `isLoading`: Boolean

### Component State
- **Dashboard**: Environment list, metrics
- **Chat**: Messages, conversation ID
- **SetupWizard**: Configuration steps

## 🎨 UI/UX Design

### Design Principles
1. **Self-Service**: Users can do everything themselves
2. **Guided**: Wizard-based configuration
3. **Clear**: Obvious next steps
4. **Professional**: Azure branding throughout
5. **Responsive**: Works on all devices

### Color Scheme
- **Primary**: Azure Blue (`#0078d4`)
- **Secondary**: Azure Purple (`#5e5ce6`)
- **Success**: Green (`#107c10`)
- **Warning**: Orange (`#f7630c`)
- **Error**: Red (`#d13438`)

### Components Hierarchy
```
App
├── AuthProvider
    ├── LoginPage (not authenticated)
    └── Dashboard (authenticated)
        ├── Empty State → SetupWizard
        └── Environment View
            ├── Environment Header
            ├── Quick Actions
            ├── Chat Interface (toggle)
            └── SetupWizard (modal)
```

## 🔌 API Integration

### Backend Requirements

Your platform backend needs to provide:

#### 1. Authentication API
```
POST /api/auth/login
POST /api/auth/logout
GET /api/auth/user
```

#### 2. Deployment API
```
POST /api/deployments
- Creates Azure resources using main.parameters.json config
- Returns deployment_id

GET /api/deployments/{id}/status
- Returns current deployment status
- Updates progress percentage
```

#### 3. Environment API
```
GET /api/environments
- Lists user's environments

POST /api/environments
- Creates new environment configuration

DELETE /api/environments/{id}
- Deletes environment
```

#### 4. Per-Environment APIs
```
Each environment has its own orchestrator endpoint:
- POST {orchestrator_endpoint}/chat
- POST {orchestrator_endpoint}/feedback
- GET {orchestrator_endpoint}/config
- GET {orchestrator_endpoint}/metrics
```

## 🔧 Configuration Mapping

### From `main.parameters.json` to Frontend

| main.parameters.json | Frontend Config | Setup Wizard Step |
|----------------------|-----------------|-------------------|
| `environmentName` | `environment_name` | Step 1 |
| `location` | `location` | Step 3 |
| `networkIsolation` | `network_isolation` | Step 4 |
| `enableAgenticRetrieval` | `enable_agentic_retrieval` | Step 4 |
| `deployCosmosDb` | `deploy_cosmos_db` | Step 4 |
| `deployVM` | `deploy_vm` | Step 4 |
| `modelDeploymentList[0].model` | `chat_model` | Step 5 |
| `modelDeploymentList[1].model` | `embedding_model` | Step 5 |

### Environment Variables

The wizard collects and passes to deployment API:
```typescript
{
  AZURE_ENV_NAME: config.environment_name,
  AZURE_LOCATION: config.location,
  AZURE_SUBSCRIPTION_ID: config.subscription_id,
  AZURE_TENANT_ID: config.tenant_id,
  NETWORK_ISOLATION: config.network_isolation,
  ENABLE_AGENTIC_RETRIEVAL: config.enable_agentic_retrieval,
  // ... etc
}
```

## 🚦 Deployment Process

### Client-Side (Frontend)
1. User fills Setup Wizard
2. Frontend validates inputs
3. Posts configuration to backend `/api/deployments`
4. Receives `deployment_id`
5. Polls `/api/deployments/{id}/status`
6. Updates UI with progress
7. On success, environment becomes available

### Server-Side (Your Backend)
1. Receives deployment config
2. Sets environment variables from config
3. Runs `azd provision` with parameters
4. Runs post-provision scripts
5. Returns deployed resource endpoints
6. Stores environment in database

## 📱 Responsive Breakpoints

- **Desktop**: > 1024px
- **Tablet**: 768px - 1024px
- **Mobile**: < 768px

## 🔒 Security Considerations

1. **Credentials**: Never store Azure credentials in frontend
2. **Tokens**: Use secure, httpOnly cookies for auth
3. **CORS**: Configure orchestrator to accept requests from frontend
4. **Validation**: Validate all inputs before deployment
5. **Isolation**: Each user's environments are isolated

## 🧪 Testing Strategy

### Unit Tests
- AuthContext logic
- API service methods
- Form validations

### Integration Tests
- Login flow
- Setup wizard flow
- Environment switching
- Chat functionality

### E2E Tests
- Complete deployment flow
- Multi-environment management
- Document upload and chat

## 📈 Future Enhancements

- [ ] Environment templates (pre-configured setups)
- [ ] Cost monitoring dashboard
- [ ] Usage analytics
- [ ] Team collaboration (share environments)
- [ ] Advanced document management
- [ ] Backup and restore
- [ ] Environment cloning
- [ ] API key management
- [ ] Webhook integrations
- [ ] Custom domain support

## 🎯 Key Differences from Original

| Aspect | Original | New (Multi-Tenant) |
|--------|----------|-------------------|
| **Purpose** | Single chat UI | Self-service platform |
| **Users** | Single org | Multiple businesses |
| **Configuration** | Static endpoint | Dynamic per environment |
| **Deployment** | Manual/external | Wizard-guided |
| **Management** | Limited | Full environment control |
| **Authentication** | None/external | Built-in |
| **Scalability** | Single instance | Multi-tenant |

## 📝 Summary

The frontend has been transformed from a **simple chat interface** into a **comprehensive self-service platform** where each business can:

✅ **Configure** their Azure resources  
✅ **Deploy** their own RAG system  
✅ **Manage** multiple environments  
✅ **Upload** and manage documents  
✅ **Monitor** usage and costs  
✅ **Use** their personalized AI assistant  

This aligns with the `main.parameters.json` configurability and enables GPT-RAG to be a true **Solution Accelerator** that businesses can adopt with their own cloud accounts and data.

