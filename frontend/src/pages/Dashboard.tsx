import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import Header from '../components/Header';
import ChatContainer from '../components/ChatContainer';
import Sidebar from '../components/Sidebar';
import SetupWizard from './SetupWizard';
import { Message, AppConfig } from '../types';
import { apiService } from '../services/api';
import './Dashboard.css';

function Dashboard() {
  const { user, currentEnvironment, logout } = useAuth();
  const [showSetupWizard, setShowSetupWizard] = useState(false);
  const [showChat, setShowChat] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [conversationId, setConversationId] = useState<string | undefined>();
  const [isLoading, setIsLoading] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [selectedSources, setSelectedSources] = useState<Message | null>(null);
  const [config, setConfig] = useState<AppConfig>({
    orchestratorEndpoint: '',
    enableUserFeedback: true,
    userFeedbackRating: false,
  });

  const handleSendMessage = async (content: string) => {
    if (!currentEnvironment) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setIsLoading(true);

    try {
      const history = messages.map((m) => ({
        role: m.role,
        content: m.content,
      }));

      const response = await apiService.sendMessage(
        {
          message: content,
          conversation_id: conversationId,
          history,
        },
        currentEnvironment.azure_config.orchestrator_endpoint || ''
      );

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.answer,
        timestamp: new Date(),
        sources: response.sources,
      };

      setMessages((prev) => [...prev, assistantMessage]);
      setConversationId(response.conversation_id);
    } catch (error) {
      const errorMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: 'I apologize, but I encountered an error. Please ensure your environment is deployed and running.',
        timestamp: new Date(),
      };
      setMessages((prev) => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleFeedback = async (
    messageId: string,
    feedbackType: 'thumbs_up' | 'thumbs_down',
    rating?: number,
    comment?: string
  ) => {
    if (!conversationId || !currentEnvironment) return;

    try {
      await apiService.sendFeedback(
        {
          conversation_id: conversationId,
          message_id: messageId,
          feedback_type: feedbackType,
          rating,
          comment,
        },
        currentEnvironment.azure_config.orchestrator_endpoint || ''
      );

      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === messageId
            ? {
                ...msg,
                feedback: {
                  type: feedbackType,
                  rating,
                  comment,
                  timestamp: new Date(),
                },
              }
            : msg
        )
      );
    } catch (error) {
      console.error('Failed to send feedback:', error);
    }
  };

  const handleShowSources = (message: Message) => {
    setSelectedSources(message);
    setIsSidebarOpen(true);
  };

  const handleNewChat = () => {
    setMessages([]);
    setConversationId(undefined);
    setIsSidebarOpen(false);
    setSelectedSources(null);
  };

  if (showChat && currentEnvironment) {
    return (
      <div className="app">
        <Header onNewChat={handleNewChat} onBack={() => setShowChat(false)} />
        <div className="app-content">
          <ChatContainer
            messages={messages}
            isLoading={isLoading}
            onSendMessage={handleSendMessage}
            onFeedback={handleFeedback}
            onShowSources={handleShowSources}
            config={config}
          />
          <Sidebar
            isOpen={isSidebarOpen}
            onClose={() => setIsSidebarOpen(false)}
            sources={selectedSources?.sources || []}
          />
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div className="dashboard-header-left">
          <div className="logo">
            <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
              <rect width="32" height="32" rx="6" fill="url(#dashGradient)" />
              <path d="M16 8L20 12H18V16H20L16 20L12 16H14V12H12L16 8Z" fill="white" opacity="0.9" />
              <defs>
                <linearGradient id="dashGradient" x1="0" y1="0" x2="32" y2="32">
                  <stop stopColor="#0078d4" />
                  <stop offset="1" stopColor="#5e5ce6" />
                </linearGradient>
              </defs>
            </svg>
            <div>
              <h1>GPT-RAG Platform</h1>
              <p>Welcome, {user?.name}</p>
            </div>
          </div>
        </div>
        <div className="dashboard-header-right">
          <button className="logout-btn" onClick={logout}>
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
              <path
                d="M7 17H4C3.44772 17 3 16.5523 3 16V4C3 3.44772 3.44772 3 4 3H7"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
              <path
                d="M13 13L17 10L13 7"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              <path d="M17 10H7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
            Logout
          </button>
        </div>
      </div>

      <div className="dashboard-content">
        {!currentEnvironment ? (
          <div className="empty-state">
            <div className="empty-icon">
              <svg width="80" height="80" viewBox="0 0 80 80" fill="none">
                <circle cx="40" cy="40" r="36" stroke="var(--azure-blue)" strokeWidth="2" opacity="0.2" />
                <circle cx="40" cy="40" r="24" fill="var(--azure-blue)" opacity="0.1" />
                <path
                  d="M40 20L50 30H45V40H50L40 50L30 40H35V30H30L40 20Z"
                  fill="var(--azure-blue)"
                />
              </svg>
            </div>
            <h2>Get Started with GPT-RAG</h2>
            <p>Deploy your first environment to start building your AI-powered knowledge base</p>
            <button className="cta-button" onClick={() => setShowSetupWizard(true)}>
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                <path d="M10 4V16M4 10H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
              Create Environment
            </button>
          </div>
        ) : (
          <div className="environment-view">
            <div className="environment-header">
              <div className="env-info">
                <h2>{currentEnvironment.name}</h2>
                <span className={`env-badge ${currentEnvironment.deployment_status.status}`}>
                  {currentEnvironment.deployment_status.status.replace('_', ' ')}
                </span>
              </div>
              <div className="env-actions">
                <button className="btn-chat" onClick={() => setShowChat(true)}>
                  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                    <rect x="2" y="3" width="16" height="12" rx="2" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M6 7H14M6 10H11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  Open Chat
                </button>
              </div>
            </div>

            <div className="dashboard-grid">
              <div className="dashboard-card">
                <h3>Quick Actions</h3>
                <div className="action-list">
                  <button className="action-item" onClick={() => setShowChat(true)}>
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <rect x="2" y="3" width="20" height="16" rx="2" stroke="currentColor" strokeWidth="2" />
                      <path d="M7 8H17M7 12H13" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                    </svg>
                    <div>
                      <strong>Start Chatting</strong>
                      <p>Ask questions about your documents</p>
                    </div>
                  </button>
                  <button className="action-item">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <path d="M12 5V19M5 12H19" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                    </svg>
                    <div>
                      <strong>Upload Documents</strong>
                      <p>Add files to your knowledge base</p>
                    </div>
                  </button>
                  <button className="action-item">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
                      <path d="M12 7V12L15 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                    </svg>
                    <div>
                      <strong>View Analytics</strong>
                      <p>Monitor usage and performance</p>
                    </div>
                  </button>
                </div>
              </div>

              <div className="dashboard-card">
                <h3>Environment Details</h3>
                <div className="detail-list">
                  <div className="detail-item">
                    <span>Type:</span>
                    <strong>{currentEnvironment.type}</strong>
                  </div>
                  <div className="detail-item">
                    <span>Location:</span>
                    <strong>{currentEnvironment.azure_config.location}</strong>
                  </div>
                  <div className="detail-item">
                    <span>Created:</span>
                    <strong>{new Date(currentEnvironment.created_at).toLocaleDateString()}</strong>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {showSetupWizard && <SetupWizard onClose={() => setShowSetupWizard(false)} />}
    </div>
  );
}

export default Dashboard;

