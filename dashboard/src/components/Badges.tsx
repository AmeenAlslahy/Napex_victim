import { REPORT_STATUS_LABELS, RISK_LABELS } from '../api/types';

export function StatusBadge({ status }: { status: string }) {
  const className = `badge status-${status}`;
  return <span className={className}>{REPORT_STATUS_LABELS[status] ?? status}</span>;
}

export function RiskBadge({ risk }: { risk: string }) {
  const className = `badge risk-${risk}`;
  return <span className={className}>{RISK_LABELS[risk] ?? risk}</span>;
}

export function StatCard({ label, value, hint, tone }: { label: string; value: number | string; hint?: string; tone?: 'danger' | 'success' | 'info' | 'default' }) {
  return (
    <div className={`stat-card ${tone ? `tone-${tone}` : ''}`}>
      <div className="stat-value">{value}</div>
      <div className="stat-label">{label}</div>
      {hint && <div className="stat-hint">{hint}</div>}
    </div>
  );
}

export function EmptyState({ message }: { message: string }) {
  return <div className="empty-state">{message}</div>;
}
