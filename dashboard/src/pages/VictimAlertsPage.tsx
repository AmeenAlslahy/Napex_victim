import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import type { VictimNotification } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

const TYPE_LABELS: Record<string, string> = {
  case_update: 'تحديث قضية',
  files_deleted: 'تم الحذف الآمن',
  cloud_cleaned: 'تمت إزالة المحتوى',
  general: 'عام',
};

/** مركز إشعارات الضحايا — ما يصل لأجهزتهم تلقائياً */
export function VictimAlertsPage() {
  const [items, setItems] = useState<VictimNotification[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [reportId, setReportId] = useState('');
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [type, setType] = useState('case_update');

  const load = useCallback(async () => {
    try {
      setItems(await api<VictimNotification[]>('/victim/notifications/all'));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'خطأ');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function run(action: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await action();
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'خطأ');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Page title="إشعارات الضحايا" subtitle="ما يصل لأجهزة الضحايا — الحذف الآمن والإزالة السحابية تُرسل إشعاراً تلقائياً">
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      <section className="panel" style={{ marginBottom: 14 }}>
        <h2>إرسال إشعار يدوي</h2>
        <div className="status-form">
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <input dir="ltr" placeholder="معرف البلاغ (يُستنتج منه الضحية)" value={reportId} onChange={(e) => setReportId(e.target.value)} />
            <select value={type} onChange={(e) => setType(e.target.value)}>
              {Object.entries(TYPE_LABELS).map(([v, l]) => (
                <option key={v} value={v}>{l}</option>
              ))}
            </select>
          </div>
          <input placeholder="العنوان" value={title} onChange={(e) => setTitle(e.target.value)} />
          <textarea
            placeholder="نص الرسالة — كن واضحاً ومطمئناً"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            rows={3}
            style={{ fontFamily: 'inherit', padding: '10px 14px', border: '1px solid var(--border)', borderRadius: 10 }}
          />
          <button
            disabled={busy || !title || !message}
            onClick={() =>
              void run(async () => {
                await api('/victim/notify', {
                  method: 'POST',
                  body: {
                    report_id: reportId.trim() || null,
                    type,
                    title,
                    message,
                  },
                });
                setTitle('');
                setMessage('');
                setReportId('');
              })
            }
          >
            إرسال للضحية
          </button>
        </div>
      </section>

      {!items ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : items.length === 0 ? (
        <EmptyState message="لا توجد إشعارات مرسلة بعد" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>النوع</th>
              <th>العنوان</th>
              <th>الرسالة</th>
              <th>قُرئ؟</th>
              <th>التاريخ</th>
            </tr>
          </thead>
          <tbody>
            {items.map((n) => (
              <tr key={n.id}>
                <td><span className="badge status-under_review">{TYPE_LABELS[n.type] ?? n.type}</span></td>
                <td><strong>{n.title}</strong></td>
                <td className="small">{n.message}</td>
                <td>{n.read_at ? '✓' : '—'}</td>
                <td className="muted small">{new Date(n.created_at).toLocaleString('ar')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
