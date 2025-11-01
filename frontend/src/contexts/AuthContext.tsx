import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { User, Environment } from '../types';

interface AuthContextType {
  user: User | null;
  currentEnvironment: Environment | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  switchEnvironment: (environmentId: string) => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [currentEnvironment, setCurrentEnvironment] = useState<Environment | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check for existing session on mount
    const storedUser = localStorage.getItem('user');
    const storedEnvId = localStorage.getItem('current_environment_id');
    
    if (storedUser) {
      const parsedUser: User = JSON.parse(storedUser);
      setUser(parsedUser);
      
      // Set current environment
      if (storedEnvId) {
        const env = parsedUser.environments.find(e => e.id === storedEnvId);
        if (env) setCurrentEnvironment(env);
      } else if (parsedUser.environments.length > 0) {
        setCurrentEnvironment(parsedUser.environments[0]);
      }
    }
    
    setIsLoading(false);
  }, []);

  const login = async (email: string, _password: string) => {
    setIsLoading(true);
    try {
      // In production, this would call your auth API with email and password
      // For now, create a mock user
      const mockUser: User = {
        id: '1',
        email,
        name: email.split('@')[0],
        created_at: new Date(),
        environments: [],
      };
      
      setUser(mockUser);
      localStorage.setItem('user', JSON.stringify(mockUser));
    } catch (error) {
      console.error('Login failed:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
    setCurrentEnvironment(null);
    localStorage.removeItem('user');
    localStorage.removeItem('current_environment_id');
  };

  const switchEnvironment = (environmentId: string) => {
    if (!user) return;
    
    const env = user.environments.find(e => e.id === environmentId);
    if (env) {
      setCurrentEnvironment(env);
      localStorage.setItem('current_environment_id', environmentId);
    }
  };

  const refreshUser = async () => {
    // In production, fetch updated user data from API
    // For now, just reload from localStorage
    const storedUser = localStorage.getItem('user');
    if (storedUser) {
      const parsedUser: User = JSON.parse(storedUser);
      setUser(parsedUser);
      
      // Update current environment if it exists
      if (currentEnvironment) {
        const updatedEnv = parsedUser.environments.find(e => e.id === currentEnvironment.id);
        if (updatedEnv) setCurrentEnvironment(updatedEnv);
      }
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        currentEnvironment,
        isAuthenticated: !!user,
        isLoading,
        login,
        logout,
        switchEnvironment,
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

