import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import { REPORT_STATUS_LABELS, type ReportList } from '../api/types';
import { sourceLabel } from '../api/types';
import { EmptyState, RiskBadge, StatusBadge } from '../components/Badges';
import { Page } from '../components/Layout';
import type { Report } from '../api/types';

/** تصدير البلاغات المعروضة CSV (مع BOM لدعم العربية في Excel) */
function exportCsv(items: Report[]): void {
  const escape = (value: string) => `"${value.split('"').join('""')}"`;
  const rows = [
    'report_number,sender,phone,source_app,category,risk,status,created_at,content',
    ...items.map((r) =>
      [
        r.report_number ?? '',
        escape(r.sender_display),
        r.sender_phone ?? '',
        r.source_app,
        r.category,
        r.risk_level,
        r.status,
        r.created_at,
        escape(r.content),
      ].join(','),
    ),
  ];
  const blob = new Blob(['\uFEFF' + rows.join('\n')], {
    type: 'text/csv;charset=utf-8',
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `napex_reports_${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

const PAGE_SIZE = 20;

export function ReportsPage() {
  const navigate = useNavigate();
  const [data, setData] = useState<ReportList | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    setError(null);
    try {
      const params = new URLSearchParams({ page: String(page), page_size: String(PAGE_SIZE) });
      if (status) params.set('status', status);
      if (query.trim()) params.set('q', query.trim());
      setData(await api<ReportList>(`/reports?${params.toString()}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'خطأ');
    }
  }, [page, status, query]);

  useEffect(() => {
    void load();
  }, [load]);

  const totalPages = data ? Math.max(1, Math.ceil(data.total / PAGE_SIZE)) : 1;

  return (
    <Page title="البلاغات" subtitle={`${data?.total ?? '…'} بلاغ مسجل`}>
      <div className="filters">
        <input
          placeholder="بحث في المحتوى أو المرسل أو رقم البلاغ…"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setPage(1);
          }}
        />
        <select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
        >
          <option value="">كل الحالات</option>
          {Object.entries(REPORT_STATUS_LABELS)
            .filter(([value]) => ['received', 'under_review', 'investigating', 'resolved', 'closed', 'rejected'].includes(value))
            .map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
        </select>
        <button className="btn-ghost" onClick={() => void load()}>تحديث</button>
        <button
          className="btn-ghost"
          disabled={!data || data.items.length === 0}
          onClick={() => exportCsv(data?.items ?? [])}
        >
          تصدير CSV
        </button>
      </div>

      {error && <EmptyState message={error} />}
      {!error && !data && <EmptyState message="جارٍ التحميل…" />}
      {!error && data && data.items.length === 0 && (
        <EmptyState message="لا توجد بلاغات مطابقة" />
      )}

      {data && data.items.length > 0 && (
        <table className="reports-table">
          <thead>
            <tr>
              <th>رقم البلاغ</th>
              <th>المرسل</th>
              <th>المصدر</th>
              <th>التصنيف</th>
              <th>الخطورة</th>
              <th>الحالة</th>
              <th>التاريخ</th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((report) => (
              <tr key={report.id} onClick={() => navigate(`/reports/${report.id}`)}>
                <td dir="ltr" className="mono">{report.report_number ?? report.local_id.slice(0, 8)}</td>
                <td>{report.sender_display}</td>
                <td>{sourceLabel(report.source_app)}</td>
                <td>{categoryLabel(report.category)}</td>
                <td><RiskBadge risk={report.risk_level} /></td>
                <td><StatusBadge status={report.status} /></td>
                <td className="muted">{new Date(report.created_at).toLocaleString('ar')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <div className="pagination">
        <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>السابق</button>
        <span>صفحة {page} من {totalPages}</span>
        <button disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>التالي</button>
      </div>
    </Page>
  );
}

export function categoryLabel(category: string): string {
  const labels: Record<string, string> = {
    normal: 'عادي',
    spam: 'إعلانات',
    suspicious: 'مشبوه',
    threat: 'تهديد',
    extortion: 'ابتزاز',
    harmful: 'محتوى ضار',
  };
  return labels[category] ?? category;
}
