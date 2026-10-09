import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

interface AuditEntry {
  id: string;
  actor: string;
  action: string;
  entity_type: string;
  entity_id?: string | null;
  details?: Record<string, unknown> | null;
  created_at: string;
}

/** سجل التدقيق — كل إجراء في النظام موثق */
export function AuditPage() {
  const [logs, setLogs] = useState<AuditEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [action, setAction] = useState('');

  const load = useCallback(async () => {
    setError(null);
    try {
      const params = new URLSearchParams({ limit: '300' });
      if (action) params.set('action', action);
      setLogs(await api<AuditEntry[]>(`/admin/audit?${params.toString()}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'خطأ');
    }
  }, [action]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <Page title="سجل التدقيق" subtitle="كل إجراء في المنصة موثق بالمُجري والزمن">
      <div className="filters">
        <select value={action} onChange={(e) => setAction(e.target.value)}>
          <option value="">كل الإجراءات</option>
          {[
            'report_received', 'report_submitted', 'report_status_changed',
            'report_feedback', 'evidence_uploaded', 'forensic_case_opened',
            'forensic_secure_erase', 'legal_order_issued', 'legal_order_executed',
            'user_role_changed', 'user_deactivated',
          ].map((a) => (
            <option key={a} value={a}>{a}</option>
          ))}
        </select>
        <button className="btn-ghost" onClick={() => void load()}>تحديث</button>
      </div>

      {error && <EmptyState message={error} />}
      {!error && !logs && <EmptyState message="جارٍ التحميل…" />}
      {!error && logs && logs.length === 0 && <EmptyState message="لا توجد سجلات مطابقة" />}

      {logs && logs.length > 0 && (
        <table className="reports-table">
          <thead>
            <tr>
              <th>الإجراء</th>
              <th>المُجري</th>
              <th>الكيان</th>
              <th>التفاصيل</th>
              <th>الزمن</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id}>
                <td><span className="badge status-under_review">{log.action}</span></td>
                <td dir="ltr" className="mono small">{log.actor}</td>
                <td className="small">{log.entity_type}</td>
                <td className="small muted">
                  {log.details ? JSON.stringify(log.details).slice(0, 60) : '—'}
                </td>
                <td className="muted small">{new Date(log.created_at).toLocaleString('ar')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
