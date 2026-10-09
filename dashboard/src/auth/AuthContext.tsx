/** سياق المصادقة — تسجيل دخول لوحة التحكم وحماية المسارات */
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { api, loadTokens, saveTokens } from '../api/client';
import type { Tokens, User } from '../api/types';

interface AuthContextValue {
  user: User | null;
  isAuthenticated: boolean;
  login: (phoneNumber: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const DASHBOARD_ROLES = new Set(['admin', 'supervisor', 'investigator']);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [tokens, setTokens] = useState<Tokens | null>(() => {
    const stored = loadTokens();
    if (!stored) return null;
    if (!stored.user || !DASHBOARD_ROLES.has(stored.user.role)) return null;
    return stored;
  });

  const login = useCallback(async (phoneNumber: string, password: string) => {
    const result = await api<Tokens>('/auth/login', {
      method: 'POST',
      body: { phone_number: phoneNumber, password },
    });
    if (!result.user || !DASHBOARD_ROLES.has(result.user.role)) {
      throw new Error('هذا الحساب ليس حساب لوحة تحكم');
    }
    saveTokens(result);
    setTokens(result);
  }, []);

  const logout = useCallback(() => {
    saveTokens(null);
    setTokens(null);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user: tokens?.user ?? null,
      isAuthenticated: tokens !== null,
      login,
      logout,
    }),
    [tokens, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}
