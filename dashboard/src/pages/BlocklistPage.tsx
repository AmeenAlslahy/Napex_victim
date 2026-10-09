import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import type { BlocklistEntry } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

/** قائمة الحظر الوطنية — تُزامَن لكل أجهزة الضحايا وتفحص تلقائياً */
export function BlocklistPage() {
  const [entries, setEntries] = useState<BlocklistEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [senderHash, setSenderHash] = useState('');
  const [phone, setPhone] = useState('');
  const [name, setName] = useState('');
  const [reason, setReason] = useState('convicted_extortion');

  const load = useCallback(async () => {
    try {
      setEntries(await api<BlocklistEntry[]>('/blocklist'));
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
      title="قائمة الحظر الوطنية"
      subtitle="مُدانو الابتزاز — تطبيقات الضحايا تتحقق منهم تلقائياً عند وصول أي رسالة"
    >
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      <section className="panel" style={{ marginBottom: 14 }}>
        <h2>إضافة مرسل للقائمة</h2>
        <div className="status-form">
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <input dir="ltr" placeholder="Sender Hash (SHA-256)" value={senderHash} onChange={(e) => setSenderHash(e.target.value)} />
            <input dir="ltr" placeholder="رقم الهاتف (اختياري)" value={phone} onChange={(e) => setPhone(e.target.value)} />
            <input placeholder="الاسم المعروض" value={name} onChange={(e) => setName(e.target.value)} />
            <input placeholder="السبب (مثال: convicted_extortion)" value={reason} onChange={(e) => setReason(e.target.value)} />
          </div>
          <button
            disabled={busy || (!senderHash && !phone)}
            onClick={() =>
              void run(async () => {
                await api('/blocklist', {
                  method: 'POST',
                  body: {
                    sender_hash: senderHash.trim() || null,
                    phone_number: phone.trim() || null,
                    display_name: name,
                    reason,
                  },
                });
                setSenderHash('');
                setPhone('');
                setName('');
              })
            }
          >
            إضافة للقائمة الوطنية
          </button>
        </div>
      </section>

      {!entries ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : entries.length === 0 ? (
        <EmptyState message="القائمة فارغة" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>المرسل</th>
              <th>الهاش</th>
              <th>الهاتف</th>
              <th>السبب</th>
              <th>تاريخ الإضافة</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e) => (
              <tr key={e.id}>
                <td>{e.display_name || '—'}</td>
                <td dir="ltr" className="mono small">{e.sender_hash ? e.sender_hash.slice(0, 20) + '…' : '—'}</td>
                <td dir="ltr" className="mono">{e.phone_number ?? '—'}</td>
                <td className="small">{e.reason}</td>
                <td className="muted small">{new Date(e.added_at).toLocaleDateString('ar')}</td>
                <td>
                  <button
                    className="btn-ghost"
                    disabled={busy}
                    onClick={() =>
                      void run(async () => {
                        await api(`/blocklist/${e.id}`, { method: 'DELETE' });
                      })
                    }
                  >
                    إزالة
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
