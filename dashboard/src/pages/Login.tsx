import { type FormEvent, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export function Login() {
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (isAuthenticated) {
    navigate('/', { replace: true });
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(phone.trim(), password);
      navigate('/', { replace: true });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'فشل تسجيل الدخول');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={handleSubmit}>
        <div className="login-brand">🛡️ NAP-EX</div>
        <div className="login-sub">لوحة التحكم الوطنية لمكافحة الابتزاز الإلكتروني</div>

        <label>رقم الهاتف</label>
        <input
          dir="ltr"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="+967000000000"
          required
        />

        <label>كلمة المرور</label>
        <input
          type="password"
          dir="ltr"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
          required
        />

        {error && <div className="login-error">{error}</div>}

        <button type="submit" disabled={busy}>
          {busy ? 'جارٍ التحقق…' : 'دخول'}
        </button>

        <div className="login-hint">
          حسابات تجريبية (بعد تشغيل الخادم):
          <br />
          مدير: <code dir="ltr">+967000000000 / Admin@123</code>
          <br />
          محقق: <code dir="ltr">+967000000001 / Inv@123</code>
        </div>
      </form>
    </div>
  );
}
