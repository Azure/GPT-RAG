import axios, { AxiosInstance } from 'axios';
import { ChatRequest, ChatResponse, FeedbackRequest, AppConfig, Document, DocumentListResponse, DashboardMetrics } from '../types';

class ApiService {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 120000, // 2 minutes timeout
    });
  }

  // Create a client for a specific environment
  private getClient(orchestratorEndpoint: string) {
    return axios.create({
      baseURL: orchestratorEndpoint,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 120000,
    });
  }

  async sendMessage(request: ChatRequest, orchestratorEndpoint: string): Promise<ChatResponse> {
    try {
      const client = this.getClient(orchestratorEndpoint);
      const response = await client.post<ChatResponse>('/chat', request);
      return response.data;
    } catch (error) {
      console.error('Error sending message:', error);
      throw new Error('Failed to send message. Please check your environment configuration.');
    }
  }

  async sendFeedback(request: FeedbackRequest, orchestratorEndpoint: string): Promise<void> {
    try {
      const client = this.getClient(orchestratorEndpoint);
      await client.post('/feedback', request);
    } catch (error) {
      console.error('Error sending feedback:', error);
      throw new Error('Failed to send feedback.');
    }
  }

  async getConfig(orchestratorEndpoint: string): Promise<AppConfig> {
    try {
      const client = this.getClient(orchestratorEndpoint);
      const response = await client.get<AppConfig>('/config');
      return response.data;
    } catch (error) {
      console.error('Error fetching config:', error);
      // Return default config if endpoint doesn't exist
      return {
        orchestratorEndpoint,
        enableUserFeedback: true,
        userFeedbackRating: false,
      };
    }
  }

  async healthCheck(orchestratorEndpoint: string): Promise<boolean> {
    try {
      const client = this.getClient(orchestratorEndpoint);
      await client.get('/health');
      return true;
    } catch (error) {
      return false;
    }
  }

  // Document Management APIs
  async uploadDocument(file: File, container: string, storageEndpoint: string): Promise<Document> {
    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('container', container);

      const response = await axios.post<Document>(`${storageEndpoint}/upload`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      return response.data;
    } catch (error) {
      console.error('Error uploading document:', error);
      throw new Error('Failed to upload document.');
    }
  }

  async listDocuments(storageEndpoint: string): Promise<DocumentListResponse> {
    try {
      const response = await axios.get<DocumentListResponse>(`${storageEndpoint}/documents`);
      return response.data;
    } catch (error) {
      console.error('Error listing documents:', error);
      throw new Error('Failed to list documents.');
    }
  }

  async deleteDocument(documentId: string, storageEndpoint: string): Promise<void> {
    try {
      await axios.delete(`${storageEndpoint}/documents/${documentId}`);
    } catch (error) {
      console.error('Error deleting document:', error);
      throw new Error('Failed to delete document.');
    }
  }

  // Dashboard & Metrics APIs
  async getDashboardMetrics(orchestratorEndpoint: string): Promise<DashboardMetrics> {
    try {
      const client = this.getClient(orchestratorEndpoint);
      const response = await client.get<DashboardMetrics>('/metrics');
      return response.data;
    } catch (error) {
      console.error('Error fetching metrics:', error);
      // Return default metrics
      return {
        total_documents: 0,
        total_conversations: 0,
        total_queries: 0,
        average_response_time: 0,
        user_satisfaction: 0,
        storage_used: 0,
        estimated_monthly_cost: 0,
      };
    }
  }

  // Deployment Management APIs (these would call your backend API, not orchestrator)
  async deployEnvironment(config: any): Promise<{ deployment_id: string }> {
    try {
      // This would call your platform API to trigger deployment
      const response = await axios.post('/api/deployments', config);
      return response.data;
    } catch (error) {
      console.error('Error deploying environment:', error);
      throw new Error('Failed to deploy environment.');
    }
  }

  async getDeploymentStatus(deploymentId: string): Promise<any> {
    try {
      const response = await axios.get(`/api/deployments/${deploymentId}/status`);
      return response.data;
    } catch (error) {
      console.error('Error getting deployment status:', error);
      throw new Error('Failed to get deployment status.');
    }
  }
}

export const apiService = new ApiService();
