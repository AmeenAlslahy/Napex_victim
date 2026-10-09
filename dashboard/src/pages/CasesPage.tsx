import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import type { CaseRecord } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

const CASE_STATUS_LABELS: Record<string, string> = {
  open: 'مفتوحة',
  investigating: 'قيد التحقيق',
  resolved: 'تم الحل',
  closed: 'مغلقة',
};

const PRIORITY_LABELS: Record<string, string> = {
  low: 'منخفضة',
  medium: 'متوسطة',
  high: 'عالية',
  critical: 'حرجة',
};

/** صفحة القضايا الموحدة — تجميع البلاغات ومتابعة سير العمل */
export function CasesPage() {
  const [cases, setCases] = useState<CaseRecord[] | null>(null);
  const [selected, setSelected] = useState<CaseRecord | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [title, setTitle] = useState('');
  const [reportId, setReportId] = useState('');

  const load = useCallback(async () => {
    try {
      setCases(await api<CaseRecord[]>('/cases'));
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
    <Page title="القضايا الموحدة" subtitle="تجميع بلاغات المبتز الواحد في قضية واحدة — الربط تلقائي">
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="filters">
        <input
          placeholder="عنوان القضية"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
        <input
          dir="ltr"
          placeholder="معرف بلاغ لربطه (اختياري)"
          value={reportId}
          onChange={(e) => setReportId(e.target.value)}
        />
        <button
          disabled={busy || !title.trim()}
          onClick={() =>
            void run(async () => {
              await api('/cases', {
                method: 'POST',
                body: {
                  title: title.trim(),
                  report_id: reportId.trim() || null,
                },
              });
              setTitle('');
              setReportId('');
            })
          }
        >
          إنشاء قضية
        </button>
      </div>

      {!cases ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : cases.length === 0 ? (
        <EmptyState message="لا توجد قضايا — تُنشأ تلقائياً عند كشف «مبتز محترف»" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>رقم القضية</th>
              <th>العنوان</th>
              <th>الحالة</th>
              <th>الأولوية</th>
              <th>البلاغات</th>
              <th>الضحايا</th>
              <th>آخر تحديث</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {cases.map((c) => (
              <tr key={c.id} onClick={() => setSelected(c)} className={c.priority === 'critical' ? 'row-danger' : ''}>
                <td dir="ltr" className="mono">{c.case_number}</td>
                <td>{c.title}</td>
                <td><span className="badge status-investigating">{CASE_STATUS_LABELS[c.status] ?? c.status}</span></td>
                <td>{PRIORITY_LABELS[c.priority] ?? c.priority}</td>
                <td><strong>{c.reports_count}</strong></td>
                <td>{c.victims_count}</td>
                <td className="muted small">{new Date(c.updated_at).toLocaleString('ar')}</td>
                <td><button className="btn-ghost">إدارة</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {selected && (
        <div className="panel" style={{ marginTop: 16 }}>
          <h2>إدارة القضية {selected.case_number}</h2>
          <CaseDetailPanel case={selected} busy={busy} onRun={run} />
        </div>
      )}
    </Page>
  );
}

function CaseDetailPanel({
  case: c,
  busy,
  onRun,
}: {
  case: CaseRecord;
  busy: boolean;
  onRun: (action: () => Promise<unknown>) => Promise<void>;
}) {
  const [note, setNote] = useState('');
  const [updateTitle, setUpdateTitle] = useState('');
  const [updateMessage, setUpdateMessage] = useState('');
  const [notifyVictim, setNotifyVictim] = useState(false);

  return (
    <div className="detail-grid">
      <section className="panel">
        <h2>سير القضية</h2>
        <div className="status-form">
          <select
            value={c.status}
            disabled={busy}
            onChange={(e) =>
              void onRun(async () => {
                await api(`/cases/${c.id}`, {
                  method: 'PATCH',
                  body: { status: e.target.value },
                });
              })
            }
          >
            {Object.entries(CASE_STATUS_LABELS).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </select>
          <select
            value={c.priority}
            disabled={busy}
            onChange={(e) =>
              void onRun(async () => {
                await api(`/cases/${c.id}`, {
                  method: 'PATCH',
                  body: { priority: e.target.value },
                });
              })
            }
          >
            {Object.entries(PRIORITY_LABELS).map(([v, l]) => (
              <option key={v} value={v}>أولوية: {l}</option>
            ))}
          </select>
        </div>
        <ul className="kv-list" style={{ marginTop: 12 }}>
          <li><span>البلاغات</span><strong>{c.reports_count}</strong></li>
          <li><span>الضحايا</span><strong>{c.victims_count}</strong></li>
        </ul>
      </section>

      <section className="panel">
        <h2>ملاحظات التحقيق</h2>
        <div className="status-form">
          <textarea
            rows={2}
            placeholder="ملاحظة جديدة…"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            style={{ fontFamily: 'inherit', padding: '10px 14px', border: '1px solid var(--border)', borderRadius: 10 }}
          />
          <button
            disabled={busy || !note.trim()}
            onClick={() =>
              void onRun(async () => {
                await api(`/cases/${c.id}/notes`, {
                  method: 'POST',
                  body: { content: note },
                });
                setNote('');
              })
            }
          >
            إضافة ملاحظة
          </button>
        </div>
        <ul className="kv-list" style={{ marginTop: 12 }}>
          {(c.notes ?? []).slice(-5).reverse().map((n) => (
            <li key={n.id}>
              <span className="small">{n.content}</span>
              <strong className="muted small">{n.author_name}</strong>
            </li>
          ))}
        </ul>
      </section>

      <section className="panel">
        <h2>تحديث للضحية</h2>
        <div className="status-form">
          <input
            placeholder="عنوان التحديث"
            value={updateTitle}
            onChange={(e) => setUpdateTitle(e.target.value)}
          />
          <textarea
            rows={2}
            placeholder="نص التحديث — يصل لتطبيق الضحية إذا فعّلت الإشعار"
            value={updateMessage}
            onChange={(e) => setUpdateMessage(e.target.value)}
            style={{ fontFamily: 'inherit', padding: '10px 14px', border: '1px solid var(--border)', borderRadius: 10 }}
          />
          <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 13 }}>
            <input
              type="checkbox"
              checked={notifyVictim}
              onChange={(e) => setNotifyVictim(e.target.checked)}
            />
            إشعار الضحية بتطبيقها
          </label>
          <button
            disabled={busy || !updateTitle.trim() || !updateMessage.trim()}
            onClick={() =>
              void onRun(async () => {
                await api(`/cases/${c.id}/updates`, {
                  method: 'POST',
                  body: {
                    type: 'case_update',
                    title: updateTitle,
                    message: updateMessage,
                    notify_victim: notifyVictim,
                  },
                });
                setUpdateTitle('');
                setUpdateMessage('');
                setNotifyVictim(false);
              })
            }
          >
            إضافة التحديث
          </button>
        </div>
        <ul className="kv-list" style={{ marginTop: 12 }}>
          {(c.updates ?? []).slice(-3).reverse().map((u) => (
            <li key={u.id}>
              <span className="small">{u.title}</span>
              <strong className="muted small">{new Date(u.created_at).toLocaleDateString('ar')}</strong>
            </li>
          ))}
        </ul>
      </section>

      <section className="panel">
        <h2>البلاغات المرتبطة ({c.reports_count})</h2>
        <ul className="kv-list">
          {(c.reports ?? []).map((r) => (
            <li key={r.id}>
              <span dir="ltr" className="mono small">{r.report_number ?? '—'}</span>
              <strong className="small">{r.sender_display}</strong>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
