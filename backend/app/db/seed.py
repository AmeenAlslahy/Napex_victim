"""تهيئة بيانات أولية — حسابات لوحة التحكم التجريبية"""
import logging

from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.user import User

logger = logging.getLogger("napex.seed")

# ⚠️ حسابات تجريبية — غيّر كلمات المرور في الإنتاج
DASHBOARD_USERS = [
    ("+967000000000", "مدير النظام", "admin", "Admin@123"),
    ("+967000000001", "محقق أول", "investigator", "Inv@123"),
    ("+967000000002", "مشرف القضايا", "supervisor", "Sup@123"),
]


def seed_dashboard_users(db: Session) -> None:
    for phone, name, role, password in DASHBOARD_USERS:
        exists = db.query(User).filter(User.phone_number == phone).first()
        if exists:
            continue
        db.add(
            User(
                phone_number=phone,
                full_name=name,
                role=role,
                hashed_password=hash_password(password),
                is_verified=True,
            )
        )
        logger.info("Seeded %s account: %s", role, phone)
    db.commit()
