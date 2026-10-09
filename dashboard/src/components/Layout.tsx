/** الهيكل الرئيسي — شريط جانبي RTL + مؤشر اتصال مباشر (WebSocket) */
import { useEffect, useState, type ReactNode } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { loadTokens, wsUrl } from '../api/client';

type WsState = 'connecting' | 'live' | 'offline';

export function Layout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [wsState, setWsState] = useState<WsState>('connecting');
  const [liveEvent, setLiveEvent] = useState<string | null>(null);
  const [dark, setDark] = useState(
    () => document.documentElement.dataset.theme === 'dark',
  );

  useEffect(() => {
    // استرجاع تفضيل الوضع الداكن
    const saved = localStorage.getItem('napex_theme');
    if (saved) document.documentElement.dataset.theme = saved;
  }, []);

  useEffect(() => {
    const tokens = loadTokens();
    if (!tokens?.access_token) return;

    let socket: WebSocket | null = null;
    let closed = false;
    let retryTimer: ReturnType<typeof setTimeout> | null = null;
    let pingTimer: ReturnType<typeof setInterval> | null = null;

    function connect() {
      if (closed) return;
      setWsState('connecting');
      socket = new WebSocket(wsUrl(tokens!.access_token));

      socket.onopen = () => {
        setWsState('live');
        pingTimer = setInterval(() => socket?.send('ping'), 25_000);
      };
      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data) as { type: string; report?: { report_number?: string }; report_number?: string; status?: string };
          if (data.type === 'new_report' && data.report) {
            setLiveEvent(`بلاغ جديد: ${data.report.report_number ?? ''}`);
          } else if (data.type === 'status_change') {
            setLiveEvent(`تحديث حالة: ${data.report_number ?? ''} → ${data.status ?? ''}`);
          }
        } catch {
          /* تجاهل */
        }
      };
      socket.onclose = () => {
        setWsState('offline');
        if (pingTimer) clearInterval(pingTimer);
        if (!closed) {
          retryTimer = setTimeout(connect, 5_000);
        }
      };
      socket.onerror = () => socket?.close();
    }

    connect();

    return () => {
      closed = true;
      if (retryTimer) clearTimeout(retryTimer);
      if (pingTimer) clearInterval(pingTimer);
      socket?.close();
    };
  }, []);

  useEffect(() => {
    if (!liveEvent) return;
    const timer = setTimeout(() => setLiveEvent(null), 6_000);
    return () => clearTimeout(timer);
  }, [liveEvent]);

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-icon">🛡️</span>
          <div>
            <div className="brand-name">NAP-EX</div>
            <div className="brand-sub">لوحة التحكم الوطنية</div>
          </div>
        </div>

        <nav>
          <NavLink to="/" end>نظرة عامة</NavLink>
          <NavLink to="/reports">البلاغات</NavLink>
          <NavLink to="/cases">القضايا</NavLink>
          <NavLink to="/forensic">التحقيق الجنائي</NavLink>
          <NavLink to="/legal">الأوامر القانونية</NavLink>
          <NavLink to="/cloud">الحذف السحابي</NavLink>
          <NavLink to="/patterns">تحليل الأنماط</NavLink>
          <NavLink to="/blocklist">قائمة الحظر</NavLink>
          <NavLink to="/alerts">إشعارات الضحايا</NavLink>
          <NavLink to="/international">التعاون الدولي</NavLink>
          <NavLink to="/users">المستخدمون</NavLink>
          <NavLink to="/audit">سجل التدقيق</NavLink>
        </nav>

        <div className="sidebar-footer">
          <div className="ws-indicator" data-state={wsState}>
            <span className="dot" />
            {wsState === 'live' ? 'اتصال مباشر' : wsState === 'connecting' ? 'جارٍ الاتصال…' : 'غير متصل'}
          </div>
          <button
            className="btn-ghost theme-toggle"
            onClick={() => {
              const next =
                document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
              document.documentElement.dataset.theme = next;
              localStorage.setItem('napex_theme', next);
              setDark(next === 'dark');
            }}
          >
            {dark ? '☀️ الوضع الفاتح' : '🌙 الوضع الداكن'}
          </button>
          <div className="user-box">
            <div className="user-name">{user?.full_name ?? user?.phone_number}</div>
            <div className="user-role">{roleLabel(user?.role)}</div>
            <button
              className="btn-ghost"
              onClick={() => {
                logout();
                navigate('/login');
              }}
            >
              تسجيل الخروج
            </button>
          </div>
        </div>
      </aside>

      <main className="content">
        {liveEvent && <div className="live-toast">{liveEvent}</div>}
        <Outlet />
      </main>
    </div>
  );
}

export function roleLabel(role?: string | null): string {
  switch (role) {
    case 'admin': return 'مدير النظام';
    case 'supervisor': return 'مشرف';
    case 'investigator': return 'محقق';
    case 'victim': return 'ضحية';
    default: return role ?? '';
  }
}

export function Page({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  return (
    <div className="page">
      <header className="page-header">
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </header>
      {children}
    </div>
  );
}
