# NAP-EX — أوامر التشغيل السريعة (make <target>)
# يتطلب: make (Git Bash / WSL / choco install make)

.PHONY: install install-dev run-backend run-dashboard test test-backend test-dashboard \
        migrate migrate-new load-test docker-up docker-down lint clean help

# ============ التطبيق ============
run-backend:          ## تشغيل الخادم محلياً
	cd backend && uvicorn app.main:app --reload --port 8000

run-dashboard:        ## تشغيل لوحة التحكم محلياً
	cd dashboard && npm run dev

# ============ التثبيت ============
install:              ## تثبيت اعتماديات الخادم واللوحة
	pip install -r backend/requirements.txt
	cd dashboard && npm install

install-dev:          ## أدوات التطوير + التطبيق
	pip install -r backend/requirements.txt -r backend/requirements-dev.txt
	cd dashboard && npm install

# ============ الاختبارات ============
test: test-backend    ## كل الاختبارات

test-backend:         ## اختبارات الخادم
	cd backend && python -m pytest

test-dashboard:       ## فحص وبناء اللوحة
	cd dashboard && npm run build

lint:                 ## الفحص الثابت للتطبيق
	flutter analyze

# ============ قاعدة البيانات ============
migrate:              ## تطبيق الترحيلات
	cd backend && alembic upgrade head

migrate-new:          ## توليد ترحيل جديد (M="وصف")
	cd backend && alembic revision --autogenerate -m "$(M)"

# ============ اختبار الحمل ============
load-test:            ## 50 مستخدماً لمدة دقيقة (الخادم يجب أن يعمل)
	cd backend && locust -f tests/load/locustfile.py --headless -u 50 -r 10 -t 60s --host http://localhost:8000

# ============ Docker ============
docker-up:            ## المنظومة كاملة (Postgres+Redis+Backend+Dashboard)
	docker compose up --build -d

docker-down:          ## إيقاف المنظومة
	docker compose down

# ============ التنظيف ============
clean:                ## مخرجات البناء والكاش
	cd dashboard && rm -rf dist node_modules/.vite
	rm -rf backend/.pytest_cache backend/tmp_alembic.db
	flutter clean

help:                 ## هذه القائمة
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
