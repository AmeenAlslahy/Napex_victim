import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

interface InternationalRequest {
  id: string;
  reference_number: string;
  request_type: string;
  target_country?: string | null;
  report_id?: string | null;
  status: string;
  notes?: string | null;
  created_at: string;
  updated_at: string;
  document?: string;
}

const TYPE_LABELS: Record<string, string> = {
  interpol: 'إشعار Interpol',
  mlat: 'طلب MLAT',
  isp: 'طلب مزود خدمة',
};

const STATUS_LABELS: Record<string, string> = {
  draft: 'مسودة',
  submitted: 'مُقدَّم',
  acknowledged: 'مُقر بالاستلام',
  responded: 'تمت الإجابة',
  closed: 'مغلق',
};

const STATUS_CLASSES: Record<string, string> = {
  draft: 'status-pending',
  submitted: 'status-investigating',
  acknowledged: 'status-under_review',
  responded: 'status-resolved',
  closed: 'status-closed',
};

/** التتبع الدولي — إشعارات Interpol وطلبات MLAT والتعاون مع المزودين */
export function InternationalPage() {
  const [requests, setRequests] = useState<InternationalRequest[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<InternationalRequest | null>(null);

  const [type, setType] = useState('interpol');
  const [reportId, setReportId] = useState('');
  const [country, setCountry] = useState('');

  const load = useCallback(async () => {
    try {
      setRequests(await api<InternationalRequest[]>('/international/requests'));
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
    <Page
      title="التعاون الدولي"
      subtitle="إشعارات Interpol وطلبات MLAT — وثائق رسمية جاهزة للتقديم عبر القنوات الرسمية"
    >
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="filters">
        <select value={type} onChange={(e) => setType(e.target.value)}>
          <option value="interpol">إشعار Interpol</option>
          <option value="mlat">طلب MLAT</option>
          <option value="isp">طلب مزود خدمة</option>
        </select>
        <input
          dir="ltr"
          placeholder="معرف البلاغ"
          value={reportId}
          onChange={(e) => setReportId(e.target.value)}
        />
        <input
          placeholder="الدولة (للملاحقة عبر الحدود)"
          value={country}
          onChange={(e) => setCountry(e.target.value)}
        />
        <button
          disabled={busy || !reportId.trim()}
          onClick={() =>
            void run(async () => {
              await api('/international/requests', {
                method: 'POST',
                body: {
                  request_type: type,
                  report_id: reportId.trim(),
                  target_country: type === 'isp' ? null : country.trim() || null,
                  court_number: type === 'isp' ? 'النيابة العامة' : undefined,
                  crime_articles: type === 'mlat' ? ['حسب التشريع النافذ'] : [],
                },
              });
              setReportId('');
              setCountry('');
            })
          }
        >
          إصدار
        </button>
      </div>

      {!requests ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : requests.length === 0 ? (
        <EmptyState message="لا توجد طلبات دولية بعد" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>المرجع</th>
              <th>النوع</th>
              <th>الدولة</th>
              <th>الحالة</th>
              <th>التاريخ</th>
              <th>الوثيقة</th>
            </tr>
          </thead>
          <tbody>
            {requests.map((r) => (
              <tr key={r.id} onClick={() => setSelected(r)}>
                <td dir="ltr" className="mono">{r.reference_number}</td>
                <td>{TYPE_LABELS[r.request_type] ?? r.request_type}</td>
                <td>{r.target_country ?? '—'}</td>
                <td>
                  <span className={`badge ${STATUS_CLASSES[r.status] ?? ''}`}>
                    {STATUS_LABELS[r.status] ?? r.status}
                  </span>
                </td>
                <td className="muted small">{new Date(r.created_at).toLocaleDateString('ar')}</td>
                <td><button className="btn-ghost">عرض</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {selected && (
        <div className="panel" style={{ marginTop: 16 }}>
          <h2>وثيقة {selected.reference_number}</h2>
          <pre className="message-content" style={{ whiteSpace: 'pre-wrap' }}>
            {selected.document ?? '—'}
          </pre>
          <p className="muted small">
            للتقديم: عبر القنوات الرسمية (I-24/7 أو القنوات الدبلوماسية) — النظام يوثق الحالة فقط.
          </p>
        </div>
      )}
    </Page>
  );
}
