"""إعداد Alembic — ترحيلات قاعدة البيانات

الاستخدام (من مجلد backend):
    alembic revision --autogenerate -m "initial schema"
    alembic upgrade head
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alembic import context  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.db.base import Base  # noqa: E402
from app import models  # noqa: E402,F401 — تسجيل كل النماذج

config = context.config

# رابط القاعدة من الإعدادات (يتيح التبديل SQLite/PostgreSQL)
config.set_main_option("sqlalchemy.url", get_settings().database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    from sqlalchemy import create_engine

    connectable = create_engine(config.get_main_option("sqlalchemy.url"))
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
