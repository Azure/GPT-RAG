// ============================================================================
// MESSAGE & CHAT TYPES
// ============================================================================

export interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  sources?: Source[];
  feedback?: Feedback;
}

export interface Source {
  title: string;
  content: string;
  filepath?: string;
  page?: number;
  url?: string;
  category?: string;
}

export interface Feedback {
  type: 'thumbs_up' | 'thumbs_down';
  rating?: number;
  comment?: string;
  timestamp: Date;
}

export interface ChatRequest {
  message: string;
  conversation_id?: string;
  history?: Array<{ role: string; content: string }>;
}

export interface ChatResponse {
  answer: string;
  conversation_id: string;
  sources?: Source[];
  error?: string;
}

export interface FeedbackRequest {
  conversation_id: string;
  message_id: string;
  feedback_type: 'thumbs_up' | 'thumbs_down';
  rating?: number;
  comment?: string;
}

// ============================================================================
// USER & AUTHENTICATION TYPES
// ============================================================================

export interface User {
  id: string;
  email: string;
  name: string;
  created_at: Date;
  environments: Environment[];
  current_environment_id?: string;
}

export interface AuthCredentials {
  email: string;
  password: string;
}

// ============================================================================
// ENVIRONMENT & DEPLOYMENT TYPES
// ============================================================================

export interface Environment {
  id: string;
  name: string;
  type: 'development' | 'staging' | 'production';
  azure_config: AzureConfiguration;
  deployment_status: DeploymentStatus;
  created_at: Date;
  updated_at: Date;
}

export interface AzureConfiguration {
  // Core Azure Settings
  subscription_id: string;
  tenant_id: string;
  resource_group: string;
  location: string;
  environment_name: string;

  // Service Endpoints (populated after deployment)
  orchestrator_endpoint?: string;
  frontend_endpoint?: string;
  data_ingest_endpoint?: string;
  
  // Resource Names (auto-generated or custom)
  ai_foundry_account_name?: string;
  search_service_name?: string;
  storage_account_name?: string;
  cosmos_db_name?: string;
  key_vault_name?: string;
  app_config_name?: string;
  container_registry_name?: string;

  // Deployment Options (from main.parameters.json)
  network_isolation: boolean;
  use_uai: boolean;
  enable_agentic_retrieval: boolean;
  deploy_ai_foundry: boolean;
  deploy_cosmos_db: boolean;
  deploy_vm: boolean;
  deploy_mcp: boolean;
  
  // Model Configuration
  chat_model: ModelDeployment;
  embedding_model: ModelDeployment;
}

export interface ModelDeployment {
  name: string;
  model: string;
  version: string;
  capacity: number;
}

export interface DeploymentStatus {
  status: 'not_started' | 'configuring' | 'deploying' | 'deployed' | 'failed' | 'updating';
  progress: number; // 0-100
  current_step?: string;
  error_message?: string;
  last_updated: Date;
  resources_deployed?: DeployedResource[];
}

export interface DeployedResource {
  name: string;
  type: string;
  status: 'provisioning' | 'running' | 'stopped' | 'failed';
  endpoint?: string;
  created_at: Date;
}

// ============================================================================
// DOCUMENT MANAGEMENT TYPES
// ============================================================================

export interface Document {
  id: string;
  filename: string;
  size: number;
  type: string;
  uploaded_at: Date;
  status: 'uploading' | 'processing' | 'indexed' | 'failed';
  container: string;
  chunks_count?: number;
  error_message?: string;
}

export interface DocumentUploadRequest {
  file: File;
  container: 'documents' | 'documents-images' | 'nl2sql';
}

export interface DocumentListResponse {
  documents: Document[];
  total_count: number;
  total_size: number;
}

// ============================================================================
// DASHBOARD & MONITORING TYPES
// ============================================================================

export interface DashboardMetrics {
  total_documents: number;
  total_conversations: number;
  total_queries: number;
  average_response_time: number;
  user_satisfaction: number; // 0-100
  storage_used: number; // bytes
  estimated_monthly_cost: number;
}

export interface ResourceUsage {
  resource_name: string;
  resource_type: string;
  current_usage: number;
  limit: number;
  unit: string;
  cost_per_unit: number;
}

export interface ConversationHistory {
  id: string;
  title: string;
  created_at: Date;
  updated_at: Date;
  message_count: number;
  preview: string;
}

// ============================================================================
// SETTINGS & CONFIGURATION TYPES
// ============================================================================

export interface AppSettings {
  environment_id: string;
  enable_user_feedback: boolean;
  user_feedback_rating: boolean;
  max_file_size_mb: number;
  allowed_file_types: string[];
  max_chat_history: number;
  enable_document_upload: boolean;
  enable_nl2sql: boolean;
  theme: 'light' | 'dark' | 'auto';
}

export interface APIKeyConfig {
  name: string;
  key: string;
  created_at: Date;
  last_used?: Date;
  expires_at?: Date;
}

// ============================================================================
// WIZARD & SETUP TYPES
// ============================================================================

export interface SetupWizardStep {
  id: number;
  title: string;
  description: string;
  completed: boolean;
  data?: any;
}

export interface DeploymentConfig {
  // Step 1: Basic Info
  environment_name: string;
  environment_type: 'development' | 'staging' | 'production';
  
  // Step 2: Azure Credentials
  subscription_id: string;
  tenant_id: string;
  client_id?: string;
  client_secret?: string;
  
  // Step 3: Location & Resources
  location: string;
  resource_group: string;
  create_new_resource_group: boolean;
  
  // Step 4: Features
  network_isolation: boolean;
  enable_agentic_retrieval: boolean;
  deploy_cosmos_db: boolean;
  deploy_vm: boolean;
  
  // Step 5: Models
  chat_model: string;
  embedding_model: string;
  
  // Step 6: Review & Deploy
  estimated_monthly_cost: number;
  deployment_time_estimate: number; // minutes
}

// ============================================================================
// API RESPONSE TYPES
// ============================================================================

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}
