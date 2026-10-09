import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../api/client';
import { RISK_LABELS, type CustodyEntry, type Evidence, type Report } from '../api/types';
import { sourceLabel } from '../api/types';
import { EmptyState, RiskBadge, StatusBadge } from '../components/Badges';
import { Page } from '../components/Layout';
import { categoryLabel } from './Reports';

export function ReportDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [report, setReport] = useState<Report | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [newStatus, setNewStatus] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    if (!id) return;
    try {
      const detail = await api<Report>(`/reports/${id}`);
      setReport(detail);
      setNewStatus(detail.status === 'received' ? 'under_review' : detail.status);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'خطأ');
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  async function updateStatus() {
    if (!id || !newStatus) return;
    setBusy(true);
    try {
      await api(`/reports/${id}/status`, {
        method: 'PATCH',
        body: { status: newStatus, note: note.trim() || undefined },
      });
      setNote('');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'خطأ');
    } finally {
      setBusy(false);
    }
  }

  if (error) return <Page title="تفاصيل البلاغ"><EmptyState message={error} /></Page>;
  if (!report) return <Page title="تفاصيل البلاغ"><EmptyState message="جارٍ التحميل…" /></Page>;

  const evidences: Evidence[] = report.evidences ?? [];
  const custody: CustodyEntry[] = report.custody ?? [];

  return (
    <Page title={`البلاغ ${report.report_number ?? ''}`} subtitle={`مسجل ${new Date(report.created_at).toLocaleString('ar')}`}>
      <button className="btn-ghost back" onClick={() => navigate('/reports')}>→ عودة للقائمة</button>

      <div className="detail-grid">
        <section className="panel">
          <h2>المرسل والرسالة</h2>
          <div className="kv">
            <span>المُرسل</span><strong>{report.sender_display}</strong>
            <span>الرقم</span><strong dir="ltr" className="mono">{report.sender_phone ?? '—'}</strong>
            <span>المصدر</span><strong>{sourceLabel(report.source_app)}</strong>
            <span>وقت الرسالة</span><strong>{new Date(report.message_timestamp).toLocaleString('ar')}</strong>
          </div>
          <blockquote className="message-content">{report.content}</blockquote>
        </section>

        <section className="panel">
          <h2>نتيجة التحليل (على الجهاز)</h2>
          <div className="kv">
            <span>التصنيف</span><strong>{categoryLabel(report.analysis.category)}</strong>
            <span>الخطورة</span><RiskBadge risk={report.risk_level} />
            <span>الثقة</span><strong>{Math.round(report.analysis.confidence * 100)}%</strong>
            <span>الحالة</span><StatusBadge status={report.status} />
          </div>
          {report.analysis.threat_phrases.length > 0 && (
            <>
              <h3>العبارات المرصودة</h3>
              <div className="chips">
                {report.analysis.threat_phrases.map((phrase) => (
                  <span key={phrase} className="chip danger">{phrase}</span>
                ))}
              </div>
            </>
          )}
          <p className="engine-note">المحرك: {report.analysis.analysis_engine ?? 'keyword-v1'} — {RISK_LABELS[report.risk_level]}</p>
        </section>

        <section className="panel">
          <h2>الأدلة ({evidences.length})</h2>
          {evidences.length === 0 ? (
            <p className="muted">لا توجد أدلة مرفوعة لهذا البلاغ</p>
          ) : (
            <ul className="kv-list">
              {evidences.map((evidence) => (
                <li key={evidence.id}>
                  <span dir="ltr" className="mono">{evidence.file_hash.slice(0, 20)}…</span>
                  <strong>
                    {evidence.verified ? '✓ مطابق' : '⚠ غير مطابق'} • {(evidence.file_size / 1024).toFixed(1)}KB
                  </strong>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="panel">
          <h2>سلسلة الحفظ (Chain of Custody)</h2>
          <ol className="timeline">
            {custody.map((entry, index) => (
              <li key={index}>
                <div className="timeline-action">{custodyActionLabel(entry.action)}</div>
                <div className="timeline-meta">
                  {entry.actor} • {new Date(entry.timestamp).toLocaleString('ar')}
                  {entry.notes && <div className="muted">{entry.notes}</div>}
                </div>
              </li>
            ))}
          </ol>
        </section>

        <section className="panel">
          <h2>تحديث الحالة</h2>
          <div className="status-form">
            <select value={newStatus} onChange={(e) => setNewStatus(e.target.value)}>
              <option value="under_review">قيد المراجعة</option>
              <option value="investigating">قيد التحقيق</option>
              <option value="resolved">تم الحل</option>
              <option value="closed">مغلق</option>
              <option value="rejected">مرفوض</option>
            </select>
            <input
              placeholder="ملاحظة (اختياري) — تُوثق في سلسلة الحفظ"
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
            <button disabled={busy} onClick={() => void updateStatus()}>
              {busy ? 'جارٍ الحفظ…' : 'حفظ التحديث'}
            </button>
          </div>
        </section>
      </div>
    </Page>
  );
}

function custodyActionLabel(action: string): string {
  const labels: Record<string, string> = {
    received_from_device: 'استلام البلاغ من الجهاز',
    evidence_received: 'استلام دليل مشفر',
  };
  if (action.startsWith('status_')) {
    return `تحديث الحالة: ${REPORT_STATUS_SIMPLE(action.slice('status_'.length))}`;
  }
  return labels[action] ?? action;
}

function REPORT_STATUS_SIMPLE(status: string): string {
  const labels: Record<string, string> = {
    under_review: 'قيد المراجعة',
    investigating: 'قيد التحقيق',
    resolved: 'تم الحل',
    closed: 'مغلق',
    rejected: 'مرفوض',
    received: 'تم الاستلام',
  };
  return labels[status] ?? status;
}
