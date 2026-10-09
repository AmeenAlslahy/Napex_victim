import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import type { CloudOrder } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

const STATUS_LABELS: Record<string, string> = {
  submitted: 'مُرسل للمزود',
  acknowledged: 'أقرّ المزود بالاستلام',
  actioned: 'تمت الإزالة ✓',
  rejected: 'مرفوض',
};

const STATUS_CLASSES: Record<string, string> = {
  submitted: 'status-investigating',
  acknowledged: 'status-under_review',
  actioned: 'status-resolved',
  rejected: 'status-rejected',
};

export function CloudPage() {
  const [orders, setOrders] = useState<CloudOrder[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      setOrders(await api<CloudOrder[]>('/cloud/orders'));
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
    <Page title="الحذف السحابي (Cloud Takedown)" subtitle="تتبع طلبات الإزالة لدى مزودي المنصات — الإزالة تلقائياً تُبلغ الضحية">
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      {!orders ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : orders.length === 0 ? (
        <EmptyState message="لا توجد طلبات إزالة سحابية — تُنشأ تلقائياً عند تنفيذ أوامر قانونية سحابية" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>رقم الطلب</th>
              <th>المزود</th>
              <th>الملفات</th>
              <th>المحاولات</th>
              <th>الحالة</th>
              <th>تاريخ الإرسال</th>
              <th>الإجراءات</th>
            </tr>
          </thead>
          <tbody>
            {orders.map((o) => (
              <tr key={o.id} className={o.status === 'actioned' ? '' : 'row-danger'}>
                <td dir="ltr" className="mono">{o.order_number}</td>
                <td dir="ltr">{o.provider}</td>
                <td>{o.files_count}</td>
                <td>{o.attempts}</td>
                <td>
                  <span className={`badge ${STATUS_CLASSES[o.status] ?? ''}`}>
                    {STATUS_LABELS[o.status] ?? o.status}
                  </span>
                </td>
                <td className="muted small">{new Date(o.submitted_at).toLocaleString('ar')}</td>
                <td>
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {o.status !== 'actioned' && (
                      <>
                        <button
                          className="btn-ghost"
                          disabled={busy}
                          onClick={() =>
                            void run(async () => {
                              await api(`/cloud/orders/${o.id}/status`, {
                                method: 'PATCH',
                                body: { status: 'acknowledged' },
                              });
                            })
                          }
                        >
                          إقرار
                        </button>
                        <button
                          disabled={busy}
                          onClick={() =>
                            void run(async () => {
                              await api(`/cloud/orders/${o.id}/status`, {
                                method: 'PATCH',
                                body: { status: 'actioned' },
                              });
                            })
                          }
                        >
                          تمت الإزالة
                        </button>
                        {o.status === 'rejected' && (
                          <button className="btn-ghost" disabled={busy}
                            onClick={() =>
                              void run(async () => {
                                await api(`/cloud/orders/${o.id}/retry`, { method: 'POST' });
                              })
                            }
                          >
                            إعادة المحاولة ({o.attempts})
                          </button>
                        )}
                      </>
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
