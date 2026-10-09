"""اختبار الحمل — Locust

التشغيل:
    locust -f tests/load/locustfile.py --host http://localhost:8000
ثم افتح http://localhost:8089 واضبط عدد المستخدمين.

تشغيل بدون واجهة (headless):
    locust -f tests/load/locustfile.py --host http://localhost:8000 \
        --headless -u 50 -r 10 -t 60s
"""
import random
import uuid

from locust import HttpUser, between, task


class VictimUser(HttpUser):
    """يحاكي تطبيق ضحية: تسجيل → تحقق → إرسال بلاغ → متابعة إشعارات"""

    wait_time = between(1, 3)

    def on_start(self):
        self.phone = f"+96779{random.randint(1000000, 9999999)}"
        response = self.client.post(
            "/api/v1/auth/register",
            json={"phone_number": self.phone, "full_name": "Load Test"},
        )
        if response.status_code == 200:
            verify = self.client.post(
                "/api/v1/auth/verify-otp",
                json={"phone_number": self.phone, "otp": "123456"},
            )
            token = verify.json().get("access_token")
            self.headers = {"Authorization": f"Bearer {token}"}
        else:
            # الحساب موجود من تشغيلة سابقة — سجل دخول بلا كلمة مرور لا يمكن؛
            # نستخدم توكن جديداً بتحقق مجدداً بعد تسجيل برقم مختلف
            self.headers = {}

    @task(3)
    def submit_report(self):
        if not self.headers:
            return
        self.client.post(
            "/api/v1/reports",
            headers=self.headers,
            json={
                "local_id": str(uuid.uuid4()),
                "sender": {
                    "raw": f"+96770{random.randint(1000000, 9999999)}",
                    "display_name": "Load Sender",
                    "sender_hash": f"load-{random.randint(1, 100)}",
                },
                "content": "عندي صورك سأنشرها إذا ما ادفعت (load test)",
                "source_app": "com.whatsapp",
                "analysis": {
                    "category": "extortion",
                    "confidence": round(random.uniform(0.7, 0.99), 2),
                    "risk_level": random.choice(["high", "critical"]),
                    "is_extortion": True,
                },
                "message_timestamp": "2026-10-05T10:00:00Z",
                "created_at": "2026-10-05T10:01:00Z",
            },
            name="POST /reports",
        )

    @task(2)
    def check_notifications(self):
        if not self.headers:
            return
        self.client.get(
            "/api/v1/victim/notifications",
            headers=self.headers,
            name="GET /victim/notifications",
        )

    @task(1)
    def health(self):
        self.client.get("/health", name="GET /health")


class InvestigatorUser(HttpUser):
    """يحاكي محققاً في لوحة التحكم"""

    wait_time = between(2, 5)
    weight = 1

    def on_start(self):
        response = self.client.post(
            "/api/v1/auth/login",
            json={"phone_number": "+967000000001", "password": "Inv@123"},
        )
        token = response.json().get("access_token", "")
        self.headers = {"Authorization": f"Bearer {token}"}

    @task(3)
    def list_reports(self):
        self.client.get(
            "/api/v1/reports?page=1&page_size=20",
            headers=self.headers,
            name="GET /reports",
        )

    @task(1)
    def stats(self):
        self.client.get(
            "/api/v1/stats/overview",
            headers=self.headers,
            name="GET /stats/overview",
        )

    @task(1)
    def patterns(self):
        self.client.get(
            "/api/v1/analysis/patterns",
            headers=self.headers,
            name="GET /analysis/patterns",
        )