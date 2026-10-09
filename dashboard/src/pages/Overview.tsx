import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { Overview } from '../api/types';
import { EmptyState, StatCard } from '../components/Badges';
import { Page } from '../components/Layout';

export function OverviewPage() {
  const [data, setData] = useState<Overview | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Overview>('/stats/overview')
      .then(setData)
      .catch((e) => setError(e instanceof Error ? e.message : 'خطأ'));
  }, []);

  if (error) return <Page title="نظرة عامة"><EmptyState message={error} /></Page>;
  if (!data) return <Page title="نظرة عامة"><EmptyState message="جارٍ التحميل…" /></Page>;

  const maxDay = Math.max(1, ...data.by_day.map((d) => d.count));

  return (
    <Page title="نظرة عامة" subtitle="الوضع اللحظي للمنصة الوطنية">
      <div className="stats-grid">
        <StatCard label="إجمالي البلاغات" value={data.total_reports} tone="info" />
        <StatCard label="بلاغات اليوم" value={data.today_reports} tone="default" />
        <StatCard label="الضحايا المسجلون" value={data.total_victims} tone="success" />
        <StatCard label="الأدلة المحفوظة" value={data.total_evidences} tone="default" />
        <StatCard label="مبتزون محترفون" value={data.professional_senders} tone="danger" hint="عدة ضحايا أو حملة ممتدة" />
      </div>

      <div className="panel-row">
        <section className="panel">
          <h2>البلاغات — آخر 14 يوماً</h2>
          <div className="bar-chart">
            {data.by_day.map((day) => (
              <div key={day.date} className="bar-col" title={`${day.date}: ${day.count}`}>
                <div
                  className="bar"
                  style={{ height: `${(day.count / maxDay) * 100}%`, minHeight: day.count > 0 ? 6 : 2 }}
                />
                <span className="bar-label">{day.date.slice(8)}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <h2>حسب الحالة</h2>
          <ul className="kv-list">
            {Object.entries(data.by_status).map(([status, count]) => (
              <li key={status}>
                <span>{statusLabel(status)}</span>
                <strong>{count}</strong>
              </li>
            ))}
          </ul>
          <h2 style={{ marginTop: 18 }}>حسب المصدر</h2>
          <ul className="kv-list">
            {Object.entries(data.by_source).map(([source, count]) => (
              <li key={source}>
                <span dir="ltr">{source}</span>
                <strong>{count}</strong>
              </li>
            ))}
          </ul>
        </section>

        <section className="panel">
          <h2>أكثر المرسلين خطورة</h2>
          {data.top_senders.length === 0 ? (
            <EmptyState message="لا توجد بيانات بعد" />
          ) : (
            <ul className="kv-list">
              {data.top_senders.map((sender) => (
                <li key={sender.sender_display}>
                  <span>
                    {sender.sender_display}
                    {sender.is_professional && <span className="badge risk-critical">محترف</span>}
                  </span>
                  <strong>
                    {sender.reports} بلاغ • {sender.victims} ضحية
                  </strong>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </Page>
  );
}

function statusLabel(status: string): string {
  const labels: Record<string, string> = {
    received: 'تم الاستلام',
    under_review: 'قيد المراجعة',
    investigating: 'قيد التحقيق',
    resolved: 'تم الحل',
    closed: 'مغلق',
    rejected: 'مرفوض',
  };
  return labels[status] ?? status;
}
