import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import type { User } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page, roleLabel } from '../components/Layout';

const ROLES = ['victim', 'investigator', 'supervisor', 'admin'] as const;

/** إدارة المستخدمين — للمدير فقط (RBAC) */
export function UsersPage() {
  const [users, setUsers] = useState<User[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      setUsers(await api<User[]>('/admin/users'));
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
    <Page title="إدارة المستخدمين" subtitle="المحققون والمشرفون والضحايا — الأدوار والحالة">
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      {!users ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>المستخدم</th>
              <th>الهاتف</th>
              <th>الدور</th>
              <th>الحالة</th>
              <th>الإجراءات</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id} className={!u.is_active ? 'row-danger' : ''}>
                <td>{u.full_name ?? '—'}</td>
                <td dir="ltr" className="mono">{u.phone_number}</td>
                <td>
                  <select
                    value={u.role}
                    disabled={busy}
                    onChange={(e) =>
                      void run(async () => {
                        await api(`/admin/users/${u.id}/role`, {
                          method: 'PATCH',
                          body: { role: e.target.value },
                        });
                      })
                    }
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r}>{roleLabel(r)}</option>
                    ))}
                  </select>
                </td>
                <td>
                  <span className={`badge ${u.is_active ? 'status-resolved' : 'status-rejected'}`}>
                    {u.is_active ? 'نشط' : 'موقوف'}
                  </span>
                </td>
                <td>
                  {u.is_active && (
                    <button
                      className="btn-ghost"
                      disabled={busy}
                      onClick={() =>
                        void run(async () => {
                          await api(`/admin/users/${u.id}/deactivate`, {
                            method: 'PATCH',
                          });
                        })
                      }
                    >
                      إيقاف
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
