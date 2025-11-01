# GPT-RAG Frontend - Multi-Tenant Self-Service Platform

A modern, self-service platform that enables businesses to deploy and manage their own GPT-RAG (Retrieval-Augmented Generation) systems using their own Azure accounts and data.

## 🎯 What This Is

**GPT-RAG Frontend** is not just a chat interface - it's a **complete deployment and management platform** where each business user can:

- ✅ **Configure** their own Azure environment
- ✅ **Deploy** their GPT-RAG instance with a guided wizard
- ✅ **Manage** multiple environments (dev, staging, production)
- ✅ **Upload** and index their private documents
- ✅ **Monitor** usage, costs, and performance
- ✅ **Chat** with their AI-powered knowledge base

## 🌟 Key Features

### 1. Self-Service Deployment
- **6-step wizard** guides users through Azure configuration
- Configure subscription, region, and features
- Choose AI models (GPT-4o, GPT-3.5-Turbo, etc.)
- Enable Zero Trust networking
- Deploy in ~45 minutes

### 2. Multi-Environment Support
- Manage dev, staging, and production environments
- Switch between environments seamlessly
- Each environment has its own Azure resources
- Isolated data and configurations

### 3. Enterprise-Grade Chat
- Real-time AI-powered Q&A
- Source attribution with document references
- User feedback collection (thumbs + ratings)
- Conversation history
- Markdown response formatting

### 4. Azure Native
- Uses Azure Container Apps
- Integrates with Azure App Configuration
- Supports Azure OpenAI models
- Azure AI Search integration
- Cosmos DB for persistence

### 5. Zero Trust Architecture
- Optional network isolation
- Private endpoints
- No public internet exposure
- Secure credential management

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- Azure subscription
- Basic understanding of Azure

### Installation

```bash
cd frontend
npm install
```

### Configuration

Create `.env` file:
```bash
cp env.example .env
```

### Development

```bash
npm run dev
```

Open http://localhost:3000

### First-Time User Flow

1. **Sign In** - Create account or login
2. **Create Environment** - Click "Create Environment"
3. **Setup Wizard** - Follow 6-step wizard:
   - Step 1: Environment details
   - Step 2: Azure credentials
   - Step 3: Location & resources
   - Step 4: Features (isolation, agentic retrieval)
   - Step 5: AI models selection
   - Step 6: Review & deploy
4. **Wait for Deployment** - ~45 minutes
5. **Start Chatting** - Upload documents and ask questions!

## 🏗️ Architecture

### Multi-Tenant Design

```
┌─────────────────────────────────────┐
│      Frontend Platform              │
│  (Login, Dashboard, Wizard, Chat)   │
└──────────┬──────────────────────────┘
           │
    ┌──────┴───────┐
    │              │
    ▼              ▼
┌─────────┐  ┌─────────┐
│ User A  │  │ User B  │
│ Azure   │  │ Azure   │
│ Env     │  │ Env     │
└─────────┘  └─────────┘
```

### Component Structure

```
frontend/
├── src/
│   ├── contexts/
│   │   └── AuthContext.tsx      # User & environment management
│   ├── pages/
│   │   ├── LoginPage.tsx        # Authentication
│   │   ├── Dashboard.tsx        # Main control center
│   │   └── SetupWizard.tsx      # Deployment wizard
│   ├── components/
│   │   ├── Header               # Navigation
│   │   ├── ChatContainer        # Chat interface
│   │   ├── MessageBubble        # Individual messages
│   │   ├── MessageInput         # Input field
│   │   ├── FeedbackButtons      # User feedback
│   │   └── Sidebar              # Sources panel
│   ├── services/
│   │   └── api.ts               # Multi-environment API client
│   └── types.ts                 # TypeScript definitions
```

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed technical documentation.

## 📋 Configuration Mapping

The Setup Wizard collects inputs that map to `infra/main.parameters.json`:

| Wizard Input | Parameter | Description |
|--------------|-----------|-------------|
| Environment Name | `environmentName` | Unique identifier |
| Location | `location` | Azure region |
| Network Isolation | `networkIsolation` | Zero Trust mode |
| Agentic Retrieval | `enableAgenticRetrieval` | Advanced RAG |
| Cosmos DB | `deployCosmosDb` | Conversation storage |
| Data Science VM | `deployVM` | Optional VM |
| Chat Model | `modelDeploymentList[0]` | GPT model |
| Embedding Model | `modelDeploymentList[1]` | Embeddings |

## 🔌 Backend Integration

### Required Backend APIs

Your platform backend needs to implement:

#### 1. Authentication
```
POST /api/auth/login
POST /api/auth/logout
GET /api/auth/user
```

#### 2. Deployment Management
```
POST /api/deployments
- Accepts wizard configuration
- Triggers Azure deployment
- Returns deployment_id

GET /api/deployments/{id}/status
- Returns deployment progress
- Shows current step
- Indicates success/failure
```

#### 3. Environment Management
```
GET /api/environments
- Lists user's environments

POST /api/environments
- Creates environment configuration

DELETE /api/environments/{id}
- Removes environment
```

#### 4. Per-Environment APIs
Each deployed environment exposes:
```
POST {orchestrator_endpoint}/chat
POST {orchestrator_endpoint}/feedback
GET {orchestrator_endpoint}/config
GET {orchestrator_endpoint}/metrics
```

## 🎨 UI/UX Design

### Microsoft Azure Theme
- Primary: Azure Blue (#0078d4)
- Secondary: Azure Purple (#5e5ce6)
- Accent: Light Blue (#50e6ff)

### Key Screens

1. **Login Page** - Beautiful gradient design with features showcase
2. **Dashboard** - Environment overview and quick actions
3. **Setup Wizard** - 6-step guided deployment
4. **Chat Interface** - Full-featured AI chat
5. **Empty States** - Helpful CTAs when no environments exist

## 🔧 Development

### Technology Stack
- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool
- **Axios** - HTTP client
- **React Markdown** - Formatted responses
- **CSS3** - Modern styling

### Available Scripts

```bash
npm run dev       # Development server
npm run build     # Production build
npm run preview   # Preview build
npm run lint      # Run linter
```

### Environment Variables

```env
# Backend API (for auth, deployments)
VITE_API_ENDPOINT=https://your-backend.com/api

# Feature flags
VITE_ENABLE_USER_FEEDBACK=true
VITE_USER_FEEDBACK_RATING=false
```

## 🐳 Docker Deployment

### Build Image
```bash
docker build -t gpt-rag-frontend .
```

### Run Container
```bash
docker run -p 80:80 \
  -e API_ENDPOINT=https://your-backend.com/api \
  gpt-rag-frontend
```

### Docker Compose
```bash
docker-compose up
```

## 🚀 Production Deployment

### Azure Container Apps

```bash
# Build and push to ACR
az acr login --name <your-acr>
docker tag gpt-rag-frontend <acr>.azurecr.io/gpt-rag-frontend:latest
docker push <acr>.azurecr.io/gpt-rag-frontend:latest

# Deploy Container App
az containerapp update \
  --name gpt-rag-frontend \
  --resource-group <rg> \
  --image <acr>.azurecr.io/gpt-rag-frontend:latest
```

## 📊 Key Differences from Original

| Aspect | Before | Now |
|--------|--------|-----|
| **Purpose** | Chat UI only | Full platform |
| **Users** | Single org | Multiple businesses |
| **Deployment** | Manual | Wizard-guided |
| **Configuration** | Static | Dynamic per user |
| **Environments** | Single | Multiple per user |
| **Management** | None | Full control |
| **Authentication** | External | Built-in |

## 🎯 Use Cases

### For Business Users
- Deploy your own RAG system without DevOps expertise
- Upload proprietary documents securely
- Get AI answers from your knowledge base
- Monitor costs and usage
- Manage multiple environments

### For MSPs/Partners
- Offer GPT-RAG as a service
- Onboard customers self-service
- Each customer isolated
- Simplified billing and management

### For Enterprises
- Development and production environments
- Test different configurations
- Gradual rollout
- Cost tracking per department

## 🔒 Security

- ✅ User authentication required
- ✅ Azure credentials never stored client-side
- ✅ Each user's data isolated
- ✅ Optional Zero Trust networking
- ✅ Private endpoints support
- ✅ Secure token management

## 📚 Documentation

- **[README.md](./README.md)** - This file (getting started)
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Technical architecture
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Deployment guide
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Development guidelines
- **[QUICKSTART.md](./QUICKSTART.md)** - 5-minute quick start

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📝 License

This project is part of the GPT-RAG Solution Accelerator.

## 🆘 Support

### Common Issues

**Q: How do I get Azure credentials?**  
A: Run `az account show` in Azure CLI to get subscription and tenant IDs.

**Q: Deployment failed, what do I do?**  
A: Check deployment logs in Azure Portal or contact support with deployment ID.

**Q: Can I switch environments?**  
A: Yes! The dashboard shows all your environments. Click any to switch.

**Q: How much does deployment cost?**  
A: Estimated $200-500/month depending on configuration and usage.

### Getting Help

- Check the documentation above
- Review [ARCHITECTURE.md](./ARCHITECTURE.md)
- Open an issue on GitHub
- Contact support

---

**Built with ❤️ for enterprise RAG deployments**

**Status**: ✅ Production Ready  
**Version**: 2.0.0 (Multi-Tenant)  
**Last Updated**: November 1, 2025
