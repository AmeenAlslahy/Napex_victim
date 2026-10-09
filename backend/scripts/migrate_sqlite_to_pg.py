"""ترحيل البيانات من SQLite إلى PostgreSQL

الاستخدام:
    1. شغّل alembic upgrade head على PostgreSQL (بعد ضبط DATABASE_URL)
    2. python scripts/migrate_sqlite_to_pg.py --source sqlite:///./napex.db

يجري: تصدير كل الجداول → تحويل الأنواع → استيراد → التحقق من الأعداد.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import create_engine, inspect, text  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.db.base import Base  # noqa: E402
from app import models  # noqa: E402,F401

TABLES_IN_ORDER = [
    "users",
    "reports",
    "evidences",
    "custody_entries",
    "forensic_cases",
    "legal_orders",
    "cloud_orders",
    "victim_notifications",
    "blocklist_entries",
    "report_feedbacks",
    "audit_logs",
    "user_consents",
    "system_config",
]


def migrate(source_url: str) -> None:
    target_url = get_settings().database_url
    if "sqlite" in target_url:
        raise SystemExit("DATABASE_URL على الهدف يجب أن يكون PostgreSQL")

    source_engine = create_engine(source_url)
    target_engine = create_engine(target_url)

    Base.metadata.create_all(bind=target_engine)
    inspector = inspect(source_engine)
    existing = set(inspector.get_table_names())

    counts: dict[str, tuple[int, int]] = {}

    with target_engine.begin() as target_conn:
        for table in TABLES_IN_ORDER:
            if table not in existing:
                print(f"⚠ {table}: غير موجودة في المصدر — تخطي")
                continue

            rows = source_engine.execute(
                text(f"SELECT * FROM {table}")
            ).mappings().all()

            if not rows:
                counts[table] = (0, 0)
                continue

            insert_sql = (
                f'INSERT INTO {table} ({", ".join(rows[0].keys())}) '
                f'VALUES ({", ".join(f":{k}" for k in rows[0].keys())}) '
                "ON CONFLICT DO NOTHING"
            )
            target_conn.execute(text(insert_sql), [dict(r) for r in rows])
            counts[table] = (len(rows), 0)
            print(f"✓ {table}: {len(rows)} صف")

    # التحقق من الأعداد
    print("\n=== التحقق ===")
    all_ok = True
    with target_engine.connect() as target_conn:
        for table, (source_count, _) in counts.items():
            target_count = target_conn.execute(
                text(f"SELECT COUNT(*) FROM {table}")
            ).scalar()
            status = "✓" if target_count >= source_count else "✗"
            if target_count < source_count:
                all_ok = False
            print(f"{status} {table}: مصدر={source_count} هدف={target_count}")

    if not all_ok:
        sys.exit(1)
    print("\n✅ الترحيل اكتمل بنجاح")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default="sqlite:///./napex.db",
        help="رابط SQLite المصدر",
    )
    args = parser.parse_args()
    migrate(args.source)
