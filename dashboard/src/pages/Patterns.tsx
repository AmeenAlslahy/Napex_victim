import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { Pattern } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';
import { categoryLabel } from './Reports';

/** صفحة تحليل الأنماط — كشف المبتزين المحترفين */
export function PatternsPage() {
  const [patterns, setPatterns] = useState<Pattern[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Pattern[]>('/analysis/patterns')
      .then(setPatterns)
      .catch((e) => setError(e instanceof Error ? e.message : 'خطأ'));
  }, []);

  if (error) return <Page title="تحليل الأنماط"><EmptyState message={error} /></Page>;
  if (!patterns) return <Page title="تحليل الأنماط"><EmptyState message="جارٍ التحميل…" /></Page>;

  const professionals = patterns.filter((p) => p.is_professional);

  return (
    <Page
      title="تحليل الأنماط"
      subtitle={`${professionals.length} مبتز محترف من أصل ${patterns.length} مُرسل — يُرتّبون بدرجة الخطورة`}
    >
      {patterns.length === 0 ? (
        <EmptyState message="لا توجد بيانات كافية بعد" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>المُرسل</th>
              <th>التصنيف</th>
              <th>الضحايا</th>
              <th>البلاغات</th>
              <th>التطبيقات</th>
              <th>مدة النشاط</th>
              <th>متوسط الثقة</th>
              <th>التقييم</th>
            </tr>
          </thead>
          <tbody>
            {patterns.map((pattern) => (
              <tr key={pattern.sender_key} className={pattern.is_professional ? 'row-danger' : ''}>
                <td>
                  <div>{pattern.sender_display}</div>
                  <div dir="ltr" className="mono muted small">{pattern.sender_phone ?? pattern.sender_key.slice(0, 16)}</div>
                </td>
                <td>{categoryLabel(pattern.dominant_category)}</td>
                <td><strong>{pattern.victims}</strong></td>
                <td>{pattern.reports}</td>
                <td className="small">{pattern.apps.length}</td>
                <td className="small">{pattern.span_days} يوم</td>
                <td>{Math.round(pattern.avg_confidence * 100)}%</td>
                <td>
                  {pattern.is_professional
                    ? <span className="badge risk-critical">مبتز محترف</span>
                    : <span className="badge status-received">مراقبة</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
