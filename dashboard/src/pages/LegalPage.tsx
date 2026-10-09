import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import type { LegalOrder } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

const TYPE_LABELS: Record<string, string> = {
  warrant: 'مذكرة تفتيش',
  takedown: 'أمر إزالة محتوى',
  seizure: 'أمر ضبط',
};

const STATUS_LABELS: Record<string, string> = {
  issued: 'صادر',
  executed: 'منفَّذ',
  returned: 'مُعاد',
};

export function LegalPage() {
  const [orders, setOrders] = useState<LegalOrder[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [orderType, setOrderType] = useState('takedown');
  const [court, setCourt] = useState('');
  const [judge, setJudge] = useState('');
  const [targetType, setTargetType] = useState('cloud');
  const [reportId, setReportId] = useState('');
  const [provider, setProvider] = useState('google');

  const load = useCallback(async () => {
    try {
      setOrders(await api<LegalOrder[]>('/legal/orders'));
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
    <Page title="السير العمل القانوني" subtitle="أوامر موثقة تولّد مستنداً رسمياً قابلاً للطباعة">
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      <section className="panel" style={{ marginBottom: 14 }}>
        <h2>إصدار أمر جديد</h2>
        <div className="status-form">
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <select value={orderType} onChange={(e) => setOrderType(e.target.value)}>
              {Object.entries(TYPE_LABELS).map(([v, l]) => (
                <option key={v} value={v}>{l}</option>
              ))}
            </select>
            <select value={targetType} onChange={(e) => setTargetType(e.target.value)}>
              <option value="device">جهاز إلكتروني</option>
              <option value="cloud">محتوى سحابي</option>
              <option value="isp">مزود خدمة</option>
            </select>
            {targetType === 'cloud' && (
              <select value={provider} onChange={(e) => setProvider(e.target.value)}>
                {['google', 'apple', 'meta', 'telegram', 'tiktok', 'snapchat', 'other'].map((p) => (
                  <option key={p} value={p}>{p}</option>
                ))}
              </select>
            )}
          </div>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <input placeholder="المحكمة / الدائرة" value={court} onChange={(e) => setCourt(e.target.value)} />
            <input placeholder="اسم القاضي" value={judge} onChange={(e) => setJudge(e.target.value)} />
            <input dir="ltr" placeholder="معرف البلاغ (اختياري)" value={reportId} onChange={(e) => setReportId(e.target.value)} />
          </div>
          <button
            disabled={busy || !court || !judge}
            onClick={() =>
              void run(async () => {
                await api('/legal/orders', {
                  method: 'POST',
                  body: {
                    order_type: orderType,
                    court_number: court,
                    judge_name: judge,
                    target_type: targetType,
                    related_report_id: reportId.trim() || null,
                  },
                });
                setCourt('');
                setJudge('');
                setReportId('');
              })
            }
          >
            إصدار الأمر
          </button>
        </div>
      </section>

      {!orders ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : orders.length === 0 ? (
        <EmptyState message="لا توجد أوامر قانونية بعد" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>رقم الأمر</th>
              <th>النوع</th>
              <th>المحكمة</th>
              <th>الهدف</th>
              <th>الحالة</th>
              <th>الإجراءات</th>
            </tr>
          </thead>
          <tbody>
            {orders.map((o) => (
              <tr key={o.id}>
                <td dir="ltr" className="mono">{o.order_number}</td>
                <td>{TYPE_LABELS[o.order_type] ?? o.order_type}</td>
                <td>{o.court_number} — {o.judge_name}</td>
                <td>{o.target_type}</td>
                <td>
                  <span className={`badge ${o.status === 'executed' ? 'status-resolved' : 'status-investigating'}`}>
                    {STATUS_LABELS[o.status] ?? o.status}
                  </span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <a
                      className="btn-ghost"
                      href={`/api/v1/legal/orders/${o.id}/document`}
                      target="_blank"
                      rel="noreferrer"
                      style={{ textDecoration: 'none', padding: '6px 12px', fontSize: 12 }}
                    >
                      المستند
                    </a>
                    {o.status !== 'executed' && (
                      <button
                        className="btn-ghost"
                        disabled={busy}
                        onClick={() =>
                          void run(async () => {
                            const result = await api<{ cloud_order_number?: string | null }>(
                              `/legal/orders/${o.id}/execute`,
                              { method: 'POST', body: { cloud_provider: provider, notes: null } },
                            );
                            if (result.cloud_order_number) {
                              setError(null);
                            }
                          })
                        }
                      >
                        تنفيذ
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
