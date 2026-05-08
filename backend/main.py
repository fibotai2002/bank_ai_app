import os
import logging
from pathlib import Path
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from sqlalchemy import select, func
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from database import init_db, User, Department, Task, Notification, Employee
from auth import hash_password
from routers import auth, tasks, users, chat, docs, notifications, stats, legacy, ws

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ── Rate Limiter ──────────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])

# ── App setup ─────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 Tashkilot AI API ishga tushmoqda...")
    await init_db()
    await _seed_demo_data()
    logger.info("✅ DB tayyor")
    yield
    logger.info("🛑 Server to'xtatilmoqda")

app = FastAPI(
    title="Tashkilot AI API",
    version="3.1.0",
    lifespan=lifespan,
    docs_url="/docs" if os.getenv("ENVIRONMENT") != "production" else None,
    redoc_url="/redoc" if os.getenv("ENVIRONMENT") != "production" else None,
)

# Rate limiter middleware
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

cors_origins = os.getenv("CORS_ORIGINS", "*")
allow_origins = ["*"] if cors_origins.strip() == "*" else [o.strip() for o in cors_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(tasks.router)
app.include_router(chat.router)
app.include_router(docs.router)
app.include_router(notifications.router)
app.include_router(stats.router)
app.include_router(legacy.router)
app.include_router(ws.router)


# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/")
async def root():
    return {"status": "ok", "app": "Tashkilot AI API v3.1 (Modular)"}


@app.get("/health")
async def health():
    """DB ulanishini ham tekshiradi"""
    try:
        from database import SessionLocal
        from sqlalchemy import text
        async with SessionLocal() as db:
            await db.execute(text("SELECT 1"))
        return {"status": "healthy", "db": "connected", "time": datetime.utcnow().isoformat()}
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {"status": "unhealthy", "db": "disconnected", "time": datetime.utcnow().isoformat()}


# ── Demo data ─────────────────────────────────────────────────────────────────
async def _seed_demo_data():
    """Birinchi ishga tushganda demo ma'lumotlar qo'shish"""
    async with __import__("database").SessionLocal() as db:
        # Foydalanuvchilar mavjudmi?
        result = await db.execute(select(func.count()).select_from(User))
        count = result.scalar()
        if count and count > 0:
            return

        # Bo'limlar
        departments = [
            Department(name="Kredit bo'limi", description="Kredit va qarz masalalari"),
            Department(name="Hisob-kitob bo'limi", description="Moliyaviy hisobotlar"),
            Department(name="IT bo'limi", description="Axborot texnologiyalari"),
            Department(name="Kadrlar bo'limi", description="Xodimlar boshqaruvi"),
            Department(name="Nazorat bo'limi", description="Audit va nazorat"),
            Department(name="Moliya bo'limi", description="Moliyaviy rejalashtirish"),
            Department(name="Yuridik bo'lim", description="Huquqiy masalalar"),
            Department(name="Xavfsizlik bo'limi", description="Xavfsizlik va himoya"),
        ]
        db.add_all(departments)
        await db.flush()

        dept_map = {d.name: d.id for d in departments}

        # Foydalanuvchilar
        users = [
            User(
                username="admin",
                password_hash=hash_password("admin123"),
                full_name="Abdulvosit Rahimov",
                role="admin",
                position="Tashkilot Rahbari",
                email="admin@tashkilot.uz",
                phone="+998901234560",
            ),
            User(
                username="manager1",
                password_hash=hash_password("pass123"),
                full_name="Alisher Karimov",
                role="manager",
                department_id=dept_map["Kredit bo'limi"],
                position="Bo'lim Boshlig'i",
                email="a.karimov@tashkilot.uz",
                phone="+998901234561",
            ),
            User(
                username="manager2",
                password_hash=hash_password("pass123"),
                full_name="Malika Yusupova",
                role="manager",
                department_id=dept_map["Hisob-kitob bo'limi"],
                position="Bo'lim Boshlig'i",
                email="m.yusupova@tashkilot.uz",
                phone="+998901234562",
            ),
            User(
                username="employee1",
                password_hash=hash_password("pass123"),
                full_name="Bobur Toshmatov",
                role="employee",
                department_id=dept_map["IT bo'limi"],
                position="Dasturchi",
                email="b.toshmatov@tashkilot.uz",
                phone="+998901234563",
            ),
            User(
                username="employee2",
                password_hash=hash_password("pass123"),
                full_name="Nilufar Rahimova",
                role="employee",
                department_id=dept_map["Kadrlar bo'limi"],
                position="Mutaxassis",
                email="n.rahimova@tashkilot.uz",
                phone="+998901234564",
            ),
            User(
                username="employee3",
                password_hash=hash_password("pass123"),
                full_name="Jasur Mirzayev",
                role="employee",
                department_id=dept_map["Nazorat bo'limi"],
                position="Inspektor",
                email="j.mirzayev@tashkilot.uz",
                phone="+998901234565",
            ),
        ]
        db.add_all(users)
        await db.flush()

        user_map = {u.username: u.id for u in users}

        # Vazifalar
        tasks = [
            Task(
                title="Oylik moliyaviy hisobot tayyorlash",
                department="Hisob-kitob bo'limi",
                department_id=dept_map["Hisob-kitob bo'limi"],
                priority="yuqori",
                status="pending",
                deadline="2026-05-10",
                source_document="Buyruq №45",
                assignee_id=user_map["manager2"],
                created_by_id=user_map["admin"],
            ),
            Task(
                title="Kredit portfelini tekshirish va tahlil qilish",
                department="Kredit bo'limi",
                department_id=dept_map["Kredit bo'limi"],
                priority="o'rta",
                status="in_progress",
                deadline="2026-05-15",
                source_document="Yo'riqnoma №12",
                assignee_id=user_map["manager1"],
                created_by_id=user_map["admin"],
            ),
            Task(
                title="Xodimlar ma'lumotlarini yangilash",
                department="Kadrlar bo'limi",
                department_id=dept_map["Kadrlar bo'limi"],
                priority="past",
                status="completed",
                deadline="2026-05-05",
                assignee_id=user_map["employee2"],
                created_by_id=user_map["manager1"],
            ),
            Task(
                title="Server xavfsizligini tekshirish",
                department="IT bo'limi",
                department_id=dept_map["IT bo'limi"],
                priority="yuqori",
                status="pending",
                deadline="2026-05-08",
                assignee_id=user_map["employee1"],
                created_by_id=user_map["admin"],
            ),
            Task(
                title="Audit hisobotini tayyorlash",
                department="Nazorat bo'limi",
                department_id=dept_map["Nazorat bo'limi"],
                priority="o'rta",
                status="pending",
                deadline="2026-05-20",
                source_document="Buyruq №50",
                assignee_id=user_map["employee3"],
                created_by_id=user_map["admin"],
            ),
        ]
        db.add_all(tasks)
        await db.flush()

        # Bildirishnomalar
        notifs = [
            Notification(
                user_id=user_map["admin"],
                title="Tizimga xush kelibsiz!",
                body="Tashkilot AI tizimi muvaffaqiyatli ishga tushirildi.",
                type="success",
            ),
            Notification(
                user_id=user_map["manager1"],
                title="Yangi vazifa berildi",
                body="Kredit portfelini tekshirish vazifasi sizga biriktirildi.",
                type="task",
            ),
            Notification(
                user_id=user_map["employee1"],
                title="Yangi vazifa",
                body="Server xavfsizligini tekshirish vazifasi sizga berildi.",
                type="task",
            ),
        ]
        db.add_all(notifs)
        await db.commit()

        # Eski Employee jadvalini ham to'ldirish (moslik uchun)
        employees = [
            Employee(telegram_id=100001, full_name="Alisher Karimov",
                     department="Kredit bo'limi", position="Bo'lim boshlig'i",
                     phone="+998901234561", email="a.karimov@tashkilot.uz"),
            Employee(telegram_id=100002, full_name="Malika Yusupova",
                     department="Hisob-kitob bo'limi", position="Bo'lim boshlig'i",
                     phone="+998901234562", email="m.yusupova@tashkilot.uz"),
            Employee(telegram_id=100003, full_name="Bobur Toshmatov",
                     department="IT bo'limi", position="Dasturchi",
                     phone="+998901234563", email="b.toshmatov@tashkilot.uz"),
        ]
        db.add_all(employees)
        await db.commit()
