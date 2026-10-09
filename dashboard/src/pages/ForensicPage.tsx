import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import type { ForensicCase } from '../api/types';
import { EmptyState } from '../components/Badges';
import { Page } from '../components/Layout';

const STATUS_LABELS: Record<string, string> = {
  opened: 'مفتوحة',
  seized: 'تم الضبط',
  imaged: 'تم التصوير',
  extracted: 'تم الاستخراج',
  erased: 'تم الحذف الآمن',
};

export function ForensicPage() {
  const [cases, setCases] = useState<ForensicCase[] | null>(null);
  const [selected, setSelected] = useState<ForensicCase | null>(null);
  const [reportId, setReportId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setCases(await api<ForensicCase[]>('/forensic/cases'));
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
    <Page title="التحقيق الجنائي الرقمي" subtitle="من الضبط إلى الحذف الآمن — كل مرحلة موثقة">
      {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="filters">
        <input
          dir="ltr"
          placeholder="معرف البلاغ لفتح قضية (اختياري)"
          value={reportId}
          onChange={(e) => setReportId(e.target.value)}
        />
        <button
          disabled={busy}
          onClick={() =>
            void run(async () => {
              await api('/forensic/cases', {
                method: 'POST',
                body: { report_id: reportId.trim() || null },
              });
              setReportId('');
            })
          }
        >
          فتح قضية جديدة
        </button>
      </div>

      {!cases ? (
        <EmptyState message="جارٍ التحميل…" />
      ) : cases.length === 0 ? (
        <EmptyState message="لا توجد قضايا جنائية بعد" />
      ) : (
        <table className="reports-table">
          <thead>
            <tr>
              <th>رقم القضية</th>
              <th>الحالة</th>
              <th>الجهاز</th>
              <th>أداة التصوير</th>
              <th>طريقة الحذف</th>
              <th>التاريخ</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {cases.map((c) => (
              <tr key={c.id} onClick={() => setSelected(c)}>
                <td dir="ltr" className="mono">{c.case_number}</td>
                <td><span className="badge status-investigating">{STATUS_LABELS[c.status] ?? c.status}</span></td>
                <td>{c.device_type ? `${c.device_type} • ${c.device_identifier}` : '—'}</td>
                <td>{c.imaging_tool ?? '—'}</td>
                <td>{c.erase_method ?? '—'}</td>
                <td className="muted small">{new Date(c.created_at).toLocaleDateString('ar')}</td>
                <td><button className="btn-ghost">إدارة</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {selected && (
        <div className="panel" style={{ marginTop: 16 }}>
          <h2>إدارة القضية {selected.case_number}</h2>
          <WorkflowPanel
            case={selected}
            busy={busy}
            onRun={run}
            onDone={async () => {
              setSelected(null);
              await load();
            }}
          />
        </div>
      )}
    </Page>
  );
}

async function runStep(
  onRun: (action: () => Promise<unknown>) => Promise<void>,
  onDone: () => Promise<void>,
  path: string,
  body: unknown,
): Promise<void> {
  await onRun(async () => {
    await api(path, { method: 'POST', body });
    await onDone();
  });
}

function WorkflowPanel({
  case: c,
  busy,
  onRun,
  onDone,
}: {
  case: ForensicCase;
  busy: boolean;
  onRun: (action: () => Promise<unknown>) => Promise<void>;
  onDone: () => Promise<void>;
}) {
  const [device, setDevice] = useState('');
  const [location, setLocation] = useState('');
  const [officers, setOfficers] = useState('');
  const [tool, setTool] = useState('Cellebrite UFED');
  const [hash, setHash] = useState('');
  const [files, setFiles] = useState('0');
  const [method, setMethod] = useState('DOD 5220.22-M');
  const [verify, setVerify] = useState('');

  return (
    <div className="detail-grid">
      {c.status === 'opened' && (
        <section className="panel">
          <h3>1. ضبط الجهاز</h3>
          <div className="status-form">
            <input dir="ltr" placeholder="معرف الجهاز (IMEI/الرقم التسلسلي)" value={device} onChange={(e) => setDevice(e.target.value)} />
            <input placeholder="مكان الضبط" value={location} onChange={(e) => setLocation(e.target.value)} />
            <input placeholder="ضباط التحقيق" value={officers} onChange={(e) => setOfficers(e.target.value)} />
            <button
              disabled={busy || !device || !location || !officers}
              onClick={() =>
                void runStep(onRun, onDone, `/forensic/cases/${c.id}/seize`, {
                  device_type: 'phone',
                  device_identifier: device,
                  seizure_location: location,
                  officers,
                })
              }
            >
              توثيق الضبط
            </button>
          </div>
        </section>
      )}

      {c.status === 'seized' && (
        <section className="panel">
          <h3>2. التصوير الجنائي (Forensic Imaging)</h3>
          <div className="status-form">
            <input dir="ltr" placeholder="الأداة (Cellebrite / FTK / dd)" value={tool} onChange={(e) => setTool(e.target.value)} />
            <input dir="ltr" placeholder="SHA-256 للنسخة الجنائية" value={hash} onChange={(e) => setHash(e.target.value)} />
            <button
              disabled={busy || hash.length < 8}
              onClick={() =>
                void runStep(onRun, onDone, `/forensic/cases/${c.id}/image`, {
                  imaging_tool: tool,
                  image_hash: hash,
                })
              }
            >
              توثيق التصوير
            </button>
          </div>
        </section>
      )}

      {c.status === 'imaged' && (
        <section className="panel">
          <h3>3. استخراج الملفات (File Carving)</h3>
          <div className="status-form">
            <input dir="ltr" placeholder="عدد الملفات المستردة" value={files} onChange={(e) => setFiles(e.target.value)} />
            <button
              disabled={busy}
              onClick={() =>
                void runStep(onRun, onDone, `/forensic/cases/${c.id}/extract`, {
                  extracted_files_count: Number(files) || 0,
                })
              }
            >
              توثيق الاستخراج
            </button>
          </div>
        </section>
      )}

      {c.status === 'extracted' && (
        <section className="panel">
          <h3>4. الحذف الآمن (Secure Erase)</h3>
          <div className="status-form">
            <input dir="ltr" placeholder="الطريقة (DOD 5220.22-M / NIST 800-88)" value={method} onChange={(e) => setMethod(e.target.value)} />
            <input dir="ltr" placeholder="هاش التحقق بعد الحذف" value={verify} onChange={(e) => setVerify(e.target.value)} />
            <button
              disabled={busy || verify.length < 8}
              onClick={() =>
                void runStep(onRun, onDone, `/forensic/cases/${c.id}/erase`, {
                  erase_method: method,
                  verification_hash: verify,
                })
              }
            >
              توثيق الحذف الآمن (+ إشعار الضحية)
            </button>
          </div>
        </section>
      )}

      {c.status === 'erased' && (
        <section className="panel">
          <h3>القضية مكتملة ✓</h3>
          <p className="muted">
            تم الحذف الآمن بطريقة <strong>{c.erase_method}</strong> — وتم إبلاغ الضحية تلقائياً.
          </p>
        </section>
      )}

      <section className="panel">
        <h3>سجل المراحل</h3>
        <ul className="kv-list">
          <li><span>الضبط</span><strong>{c.seizure_at ? '✓ ' + new Date(c.seizure_at).toLocaleString('ar') : '—'}</strong></li>
          <li><span>التصوير</span><strong>{c.image_hash ? '✓ ' + c.image_hash.slice(0, 16) + '…' : '—'}</strong></li>
          <li><span>الاستخراج</span><strong>{c.extracted_files_count != null ? `✓ ${c.extracted_files_count} ملف` : '—'}</strong></li>
          <li><span>الحذف الآمن</span><strong>{c.erase_at ? '✓ ' + new Date(c.erase_at).toLocaleString('ar') : '—'}</strong></li>
        </ul>
      </section>
    </div>
  );
}
