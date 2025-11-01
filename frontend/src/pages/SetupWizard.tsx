import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { DeploymentConfig } from '../types';
import './SetupWizard.css';

const AZURE_LOCATIONS = [
  { value: 'eastus', label: 'East US' },
  { value: 'eastus2', label: 'East US 2' },
  { value: 'westus', label: 'West US' },
  { value: 'westus2', label: 'West US 2' },
  { value: 'centralus', label: 'Central US' },
  { value: 'northeurope', label: 'North Europe' },
  { value: 'westeurope', label: 'West Europe' },
  { value: 'southeastasia', label: 'Southeast Asia' },
  { value: 'eastasia', label: 'East Asia' },
];

function SetupWizard({ onClose }: { onClose: () => void }) {
  const { refreshUser } = useAuth();
  const [currentStep, setCurrentStep] = useState(1);
  const [config, setConfig] = useState<DeploymentConfig>({
    environment_name: '',
    environment_type: 'development',
    subscription_id: '',
    tenant_id: '',
    location: 'eastus',
    resource_group: '',
    create_new_resource_group: true,
    network_isolation: false,
    enable_agentic_retrieval: false,
    deploy_cosmos_db: true,
    deploy_vm: false,
    chat_model: 'gpt-4o',
    embedding_model: 'text-embedding-3-large',
    estimated_monthly_cost: 0,
    deployment_time_estimate: 45,
  });

  const totalSteps = 6;

  const handleNext = () => {
    if (currentStep < totalSteps) {
      setCurrentStep(currentStep + 1);
    }
  };

  const handleBack = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleDeploy = async () => {
    // In production, this would call your deployment API
    console.log('Deploying with config:', config);
    await refreshUser();
    onClose();
  };

  const updateConfig = (updates: Partial<DeploymentConfig>) => {
    setConfig({ ...config, ...updates });
  };

  // Validation logic for each step
  const isStepValid = () => {
    switch (currentStep) {
      case 1:
        return config.environment_name.trim() !== '';
      case 2:
        return config.subscription_id.trim() !== '' && config.tenant_id.trim() !== '';
      case 3:
        return config.create_new_resource_group || config.resource_group.trim() !== '';
      case 4:
      case 5:
        return true; // No required fields in steps 4 and 5
      case 6:
        return true;
      default:
        return false;
    }
  };

  return (
    <div className="wizard-overlay">
      <div className="wizard-container">
        <div className="wizard-header">
          <h2>Deploy Your GPT-RAG Environment</h2>
          <button className="wizard-close" onClick={onClose}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M6 6L18 18M6 18L18 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        <div className="wizard-progress">
          {Array.from({ length: totalSteps }, (_, i) => i + 1).map((step) => (
            <div
              key={step}
              className={`progress-step ${step <= currentStep ? 'active' : ''} ${step < currentStep ? 'completed' : ''}`}
            >
              <div className="step-number">{step}</div>
              <div className="step-label">Step {step}</div>
            </div>
          ))}
        </div>

        <div className="wizard-content">
          {currentStep === 1 && (
            <div className="wizard-step">
              <h3>Environment Details</h3>
              <p>Set up basic information for your GPT-RAG deployment</p>

              <div className="form-group">
                <label>Environment Name</label>
                <input
                  type="text"
                  value={config.environment_name}
                  onChange={(e) => updateConfig({ environment_name: e.target.value })}
                  placeholder="my-rag-environment"
                />
                <small>Lowercase letters, numbers, and hyphens only</small>
              </div>

              <div className="form-group">
                <label>Environment Type</label>
                <select
                  value={config.environment_type}
                  onChange={(e) => updateConfig({ environment_type: e.target.value as any })}
                >
                  <option value="development">Development</option>
                  <option value="staging">Staging</option>
                  <option value="production">Production</option>
                </select>
              </div>
            </div>
          )}

          {currentStep === 2 && (
            <div className="wizard-step">
              <h3>Azure Credentials</h3>
              <p>Provide your Azure subscription and tenant information</p>

              <div className="form-group">
                <label>Subscription ID</label>
                <input
                  type="text"
                  value={config.subscription_id}
                  onChange={(e) => updateConfig({ subscription_id: e.target.value })}
                  placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                />
              </div>

              <div className="form-group">
                <label>Tenant ID</label>
                <input
                  type="text"
                  value={config.tenant_id}
                  onChange={(e) => updateConfig({ tenant_id: e.target.value })}
                  placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                />
              </div>

              <div className="info-box">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                  <circle cx="10" cy="10" r="9" stroke="currentColor" strokeWidth="1.5" />
                  <path d="M10 6V10M10 14H10.01" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                <div>
                  <strong>Find your IDs</strong>
                  <p>Run <code>az account show</code> in Azure CLI to get your subscription and tenant IDs</p>
                </div>
              </div>
            </div>
          )}

          {currentStep === 3 && (
            <div className="wizard-step">
              <h3>Azure Location & Resources</h3>
              <p>Choose where to deploy your resources</p>

              <div className="form-group">
                <label>Azure Region</label>
                <select value={config.location} onChange={(e) => updateConfig({ location: e.target.value })}>
                  {AZURE_LOCATIONS.map((loc) => (
                    <option key={loc.value} value={loc.value}>
                      {loc.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={config.create_new_resource_group}
                    onChange={(e) => updateConfig({ create_new_resource_group: e.target.checked })}
                  />
                  Create new resource group
                </label>
              </div>

              {!config.create_new_resource_group && (
                <div className="form-group">
                  <label>Existing Resource Group Name</label>
                  <input
                    type="text"
                    value={config.resource_group}
                    onChange={(e) => updateConfig({ resource_group: e.target.value })}
                    placeholder="existing-resource-group"
                  />
                </div>
              )}
            </div>
          )}

          {currentStep === 4 && (
            <div className="wizard-step">
              <h3>Feature Configuration</h3>
              <p>Choose which features to enable</p>

              <div className="feature-grid">
                <label className="feature-card">
                  <input
                    type="checkbox"
                    checked={config.network_isolation}
                    onChange={(e) => updateConfig({ network_isolation: e.target.checked })}
                  />
                  <div className="feature-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <rect x="3" y="11" width="18" height="11" rx="2" stroke="currentColor" strokeWidth="2" />
                      <path d="M7 11V7C7 4.79 8.79 3 11 3H13C15.21 3 17 4.79 17 7V11" stroke="currentColor" strokeWidth="2" />
                    </svg>
                  </div>
                  <div>
                    <strong>Network Isolation</strong>
                    <p>Deploy with private endpoints (Zero Trust)</p>
                  </div>
                </label>

                <label className="feature-card">
                  <input
                    type="checkbox"
                    checked={config.enable_agentic_retrieval}
                    onChange={(e) => updateConfig({ enable_agentic_retrieval: e.target.checked })}
                  />
                  <div className="feature-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
                      <path d="M12 8V12L15 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                    </svg>
                  </div>
                  <div>
                    <strong>Agentic Retrieval</strong>
                    <p>Enable advanced RAG with AI agents</p>
                  </div>
                </label>

                <label className="feature-card">
                  <input
                    type="checkbox"
                    checked={config.deploy_cosmos_db}
                    onChange={(e) => updateConfig({ deploy_cosmos_db: e.target.checked })}
                  />
                  <div className="feature-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
                      <circle cx="12" cy="12" r="4" fill="currentColor" />
                    </svg>
                  </div>
                  <div>
                    <strong>Cosmos DB</strong>
                    <p>Store conversations and feedback</p>
                  </div>
                </label>

                <label className="feature-card">
                  <input
                    type="checkbox"
                    checked={config.deploy_vm}
                    onChange={(e) => updateConfig({ deploy_vm: e.target.checked })}
                  />
                  <div className="feature-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" strokeWidth="2" />
                      <path d="M3 9H21M9 3V21" stroke="currentColor" strokeWidth="2" />
                    </svg>
                  </div>
                  <div>
                    <strong>Data Science VM</strong>
                    <p>For advanced data processing</p>
                  </div>
                </label>
              </div>
            </div>
          )}

          {currentStep === 5 && (
            <div className="wizard-step">
              <h3>AI Models</h3>
              <p>Select the models to deploy</p>

              <div className="form-group">
                <label>Chat Model</label>
                <select value={config.chat_model} onChange={(e) => updateConfig({ chat_model: e.target.value })}>
                  <option value="gpt-4o">GPT-4o (Recommended)</option>
                  <option value="gpt-4-turbo">GPT-4 Turbo</option>
                  <option value="gpt-35-turbo">GPT-3.5 Turbo (Cost-effective)</option>
                </select>
              </div>

              <div className="form-group">
                <label>Embedding Model</label>
                <select
                  value={config.embedding_model}
                  onChange={(e) => updateConfig({ embedding_model: e.target.value })}
                >
                  <option value="text-embedding-3-large">Text Embedding 3 Large (Best)</option>
                  <option value="text-embedding-3-small">Text Embedding 3 Small (Faster)</option>
                  <option value="text-embedding-ada-002">Text Embedding Ada 002 (Legacy)</option>
                </select>
              </div>

              <div className="info-box">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                  <circle cx="10" cy="10" r="9" stroke="currentColor" strokeWidth="1.5" />
                  <path d="M10 6V10M10 14H10.01" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                <div>
                  <strong>Model availability</strong>
                  <p>Ensure your selected region supports these models. Check Azure OpenAI availability.</p>
                </div>
              </div>
            </div>
          )}

          {currentStep === 6 && (
            <div className="wizard-step">
              <h3>Review & Deploy</h3>
              <p>Confirm your configuration and start deployment</p>

              <div className="config-summary">
                <div className="summary-section">
                  <h4>Environment</h4>
                  <div className="summary-item">
                    <span>Name:</span>
                    <strong>{config.environment_name || 'Not set'}</strong>
                  </div>
                  <div className="summary-item">
                    <span>Type:</span>
                    <strong>{config.environment_type}</strong>
                  </div>
                  <div className="summary-item">
                    <span>Location:</span>
                    <strong>{AZURE_LOCATIONS.find((l) => l.value === config.location)?.label}</strong>
                  </div>
                </div>

                <div className="summary-section">
                  <h4>Features</h4>
                  <div className="summary-item">
                    <span>Network Isolation:</span>
                    <strong>{config.network_isolation ? 'Yes' : 'No'}</strong>
                  </div>
                  <div className="summary-item">
                    <span>Agentic Retrieval:</span>
                    <strong>{config.enable_agentic_retrieval ? 'Yes' : 'No'}</strong>
                  </div>
                  <div className="summary-item">
                    <span>Cosmos DB:</span>
                    <strong>{config.deploy_cosmos_db ? 'Yes' : 'No'}</strong>
                  </div>
                </div>

                <div className="summary-section">
                  <h4>Models</h4>
                  <div className="summary-item">
                    <span>Chat:</span>
                    <strong>{config.chat_model}</strong>
                  </div>
                  <div className="summary-item">
                    <span>Embedding:</span>
                    <strong>{config.embedding_model}</strong>
                  </div>
                </div>

                <div className="summary-section highlight">
                  <h4>Estimated Costs</h4>
                  <div className="summary-item">
                    <span>Monthly:</span>
                    <strong>~$200 - $500</strong>
                  </div>
                  <div className="summary-item">
                    <span>Deployment Time:</span>
                    <strong>~{config.deployment_time_estimate} minutes</strong>
                  </div>
                </div>
              </div>

              <div className="warning-box">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                  <path
                    d="M10 2L18 17H2L10 2Z"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinejoin="round"
                  />
                  <path d="M10 8V11M10 14H10.01" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                <div>
                  <strong>Before deploying</strong>
                  <p>Ensure you have sufficient Azure quota and the necessary permissions to create resources.</p>
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="wizard-footer">
          <button className="btn-secondary" onClick={currentStep === 1 ? onClose : handleBack}>
            {currentStep === 1 ? 'Cancel' : 'Back'}
          </button>
          {currentStep < totalSteps ? (
            <button className="btn-primary" onClick={handleNext} disabled={!isStepValid()}>
              Next
            </button>
          ) : (
            <button className="btn-primary btn-deploy" onClick={handleDeploy}>
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                <path d="M5 10L8 13L15 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Deploy Environment
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export default SetupWizard;

