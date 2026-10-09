/** عميل HTTP — مع تحديث تلقائي للتوكن عند انتهاء الصلاحية */
import type { Tokens } from './types';

const API = import.meta.env.VITE_API_URL ?? '/api/v1';

const STORAGE_KEY = 'napex_dashboard_tokens';

export function loadTokens(): Tokens | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Tokens) : null;
  } catch {
    return null;
  }
}

export function saveTokens(tokens: Tokens | null): void {
  if (tokens === null) {
    localStorage.removeItem(STORAGE_KEY);
  } else {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(tokens));
  }
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  formData?: FormData;
  retry?: boolean;
}

let onUnauthorized: (() => void) | null = null;

export function setUnauthorizedHandler(handler: (() => void) | null): void {
  onUnauthorized = handler;
}

async function tryRefresh(): Promise<boolean> {
  const tokens = loadTokens();
  if (!tokens?.refresh_token) return false;

  const response = await fetch(`${API}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: tokens.refresh_token }),
  });
  if (!response.ok) return false;

  saveTokens((await response.json()) as Tokens);
  return true;
}

export async function api<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const tokens = loadTokens();
  const headers: Record<string, string> = {};

  if (tokens?.access_token) {
    headers.Authorization = `Bearer ${tokens.access_token}`;
  }
  if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  const response = await fetch(`${API}${path}`, {
    method: options.method ?? 'GET',
    headers,
    body: options.formData ?? (options.body !== undefined ? JSON.stringify(options.body) : undefined),
  });

  if (response.status === 401 && options.retry !== false) {
    const refreshed = await tryRefresh();
    if (refreshed) {
      return api<T>(path, { ...options, retry: false });
    }
    saveTokens(null);
    onUnauthorized?.();
  }

  if (!response.ok) {
    let message = `خطأ ${response.status}`;
    try {
      const data = (await response.json()) as { detail?: string };
      if (typeof data.detail === 'string') message = data.detail;
    } catch {
      /* تجاهل */
    }
    throw new ApiError(response.status, message);
  }

  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

export function wsUrl(token: string): string {
  const base = import.meta.env.VITE_WS_URL ?? `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}`;
  return `${base}/api/v1/ws?token=${encodeURIComponent(token)}`;
}
