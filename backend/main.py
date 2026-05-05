import os
import uuid
import aiofiles
from pathlib import Path
from datetime import datetime
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, Integer, case

from database import init_db, get_db, Employee, Task, Notification, Document, User, Department, ChatHistory
from schemas import (
    EmployeeCreate, EmployeeUpdate, EmployeeOut,
    TaskCreate, TaskUpdate, TaskOut, TaskAssign,
    ChatRequest, ChatResponse,
    NotificationOut, DocumentOut,
    LoginRequest, LoginResponse, UserOut, UserCreate, UserUpdate,
    DepartmentCreate, DepartmentOut,
)
from auth import hash_password, verify_password, create_access_token, decode_token
from ai_agent import chat_with_ai

security = HTTPBearer(auto_error=False)

# ── App setup ─────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    await _seed_demo_data()
    yield

app = FastAPI(title="Tashkilot AI API", version="3.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# ── Auth helper ───────────────────────────────────────────────────────────────
async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not credentials:
        raise HTTPException(status_code=401, detail="Token taqdim etilmagan")
    payload = decode_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Token yaroqsiz yoki muddati o'tgan")
    user_id = payload.get("user_id")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Foydalanuvchi topilmadi")
    return user


async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Faqat admin uchun")
    return current_user


async def require_manager_or_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role not in ("admin", "manager"):
        raise HTTPException(status_code=403, detail="Faqat manager yoki admin uchun")
    return current_user


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


# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/")
async def root():
    return {"status": "ok", "app": "Tashkilot AI API v3.0"}


@app.get("/health")
async def health():
    return {"status": "healthy", "time": datetime.utcnow().isoformat()}


# ── Auth ──────────────────────────────────────────────────────────────────────
@app.post("/api/auth/login", response_model=LoginResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == body.username))
    user = result.scalar_one_or_none()

    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Username yoki parol noto'g'ri")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Hisob faol emas")

    # So'nggi kirish vaqtini yangilash
    user.last_login = datetime.utcnow()
    await db.commit()

    token = create_access_token({"user_id": user.id, "role": user.role})

    dept_name = None
    if user.department_id:
        dept_result = await db.execute(select(Department).where(Department.id == user.department_id))
        dept = dept_result.scalar_one_or_none()
        dept_name = dept.name if dept else None

    return LoginResponse(
        access_token=token,
        user_id=user.id,
        username=user.username,
        full_name=user.full_name,
        role=user.role,
        department_id=user.department_id,
        department_name=dept_name,
    )


@app.get("/api/auth/me", response_model=UserOut)
async def get_me(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    dept_name = None
    if current_user.department_id:
        dept_result = await db.execute(select(Department).where(Department.id == current_user.department_id))
        dept = dept_result.scalar_one_or_none()
        dept_name = dept.name if dept else None

    return UserOut(
        id=current_user.id,
        username=current_user.username,
        full_name=current_user.full_name,
        role=current_user.role,
        department_id=current_user.department_id,
        department_name=dept_name,
        position=current_user.position,
        phone=current_user.phone,
        email=current_user.email,
        is_active=current_user.is_active,
        created_at=current_user.created_at,
    )


@app.patch("/api/auth/me", response_model=UserOut)
async def update_me(
    body: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    for k, v in body.model_dump(exclude_none=True).items():
        if k == "password":
            current_user.password_hash = hash_password(v)
        else:
            setattr(current_user, k, v)
    await db.commit()
    await db.refresh(current_user)

    dept_name = None
    if current_user.department_id:
        dept_result = await db.execute(select(Department).where(Department.id == current_user.department_id))
        dept = dept_result.scalar_one_or_none()
        dept_name = dept.name if dept else None

    return UserOut(
        id=current_user.id,
        username=current_user.username,
        full_name=current_user.full_name,
        role=current_user.role,
        department_id=current_user.department_id,
        department_name=dept_name,
        position=current_user.position,
        phone=current_user.phone,
        email=current_user.email,
        is_active=current_user.is_active,
        created_at=current_user.created_at,
    )


# ── Users (admin) ─────────────────────────────────────────────────────────────
@app.get("/api/users", response_model=list[UserOut])
async def get_users(
    current_user: User = Depends(require_manager_or_admin),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role == "admin":
        result = await db.execute(select(User).where(User.is_active == True).order_by(User.full_name))
    else:
        # Manager faqat o'z bo'limidagi xodimlarni ko'radi
        result = await db.execute(
            select(User).where(User.department_id == current_user.department_id, User.is_active == True)
        )
    users = result.scalars().all()

    out = []
    for u in users:
        dept_name = None
        if u.department_id:
            dept_result = await db.execute(select(Department).where(Department.id == u.department_id))
            dept = dept_result.scalar_one_or_none()
            dept_name = dept.name if dept else None
        out.append(UserOut(
            id=u.id, username=u.username, full_name=u.full_name,
            role=u.role, department_id=u.department_id, department_name=dept_name,
            position=u.position, phone=u.phone, email=u.email,
            is_active=u.is_active, created_at=u.created_at,
        ))
    return out


@app.post("/api/users", response_model=UserOut)
async def create_user(
    body: UserCreate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(select(User).where(User.username == body.username))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Bu username allaqachon mavjud")

    user = User(
        username=body.username,
        password_hash=hash_password(body.password),
        full_name=body.full_name,
        role=body.role,
        department_id=body.department_id,
        position=body.position,
        phone=body.phone,
        email=body.email,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    dept_name = None
    if user.department_id:
        dept_result = await db.execute(select(Department).where(Department.id == user.department_id))
        dept = dept_result.scalar_one_or_none()
        dept_name = dept.name if dept else None

    return UserOut(
        id=user.id, username=user.username, full_name=user.full_name,
        role=user.role, department_id=user.department_id, department_name=dept_name,
        position=user.position, phone=user.phone, email=user.email,
        is_active=user.is_active, created_at=user.created_at,
    )


@app.delete("/api/users/{user_id}")
async def delete_user(
    user_id: int,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    if user_id == current_user.id:
        raise HTTPException(400, "O'zingizni o'chira olmaysiz")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "Foydalanuvchi topilmadi")
    user.is_active = False
    await db.commit()
    return {"ok": True}


# ── Departments ───────────────────────────────────────────────────────────────
@app.get("/api/departments", response_model=list[DepartmentOut])
async def get_departments(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Department).order_by(Department.name))
    depts = result.scalars().all()

    out = []
    for d in depts:
        user_count_r = await db.execute(
            select(func.count()).select_from(User).where(User.department_id == d.id, User.is_active == True)
        )
        task_count_r = await db.execute(
            select(func.count()).select_from(Task).where(Task.department_id == d.id)
        )
        out.append(DepartmentOut(
            id=d.id, name=d.name, description=d.description,
            created_at=d.created_at,
            user_count=user_count_r.scalar() or 0,
            task_count=task_count_r.scalar() or 0,
        ))
    return out


@app.post("/api/departments", response_model=DepartmentOut)
async def create_department(
    body: DepartmentCreate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(select(Department).where(Department.name == body.name))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Bu bo'lim allaqachon mavjud")
    dept = Department(name=body.name, description=body.description)
    db.add(dept)
    await db.commit()
    await db.refresh(dept)
    return DepartmentOut(id=dept.id, name=dept.name, description=dept.description,
                         created_at=dept.created_at, user_count=0, task_count=0)


# ── Chat ──────────────────────────────────────────────────────────────────────
@app.post("/api/chat", response_model=ChatResponse)
async def chat(
    req: ChatRequest,
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    user_id = req.user_id
    telegram_id = req.telegram_id

    # Token orqali user_id aniqlash
    if credentials:
        payload = decode_token(credentials.credentials)
        if payload:
            user_id = payload.get("user_id")

    # Eski telegram_id bilan moslik
    if not user_id and telegram_id:
        emp_result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
        emp = emp_result.scalar_one_or_none()
        if not emp:
            emp = Employee(telegram_id=telegram_id)
            db.add(emp)
            await db.commit()

    result = await chat_with_ai(db, req.message, telegram_id or 0, user_id=user_id)
    return ChatResponse(**result)


# ── Tasks ─────────────────────────────────────────────────────────────────────
async def _task_to_out(task: Task, db: AsyncSession) -> TaskOut:
    assignee_name = None
    if task.assignee_id:
        r = await db.execute(select(User).where(User.id == task.assignee_id))
        u = r.scalar_one_or_none()
        assignee_name = u.full_name if u else None

    creator_name = None
    if task.created_by_id:
        r = await db.execute(select(User).where(User.id == task.created_by_id))
        u = r.scalar_one_or_none()
        creator_name = u.full_name if u else None

    return TaskOut(
        id=task.id, title=task.title, description=task.description,
        department=task.department, department_id=task.department_id,
        priority=task.priority, status=task.status,
        source_document=task.source_document, deadline=task.deadline,
        assignee_id=task.assignee_id, assignee_name=assignee_name,
        created_by_id=task.created_by_id, creator_name=creator_name,
        created_at=task.created_at, updated_at=task.updated_at,
    )


@app.get("/api/tasks", response_model=list[TaskOut])
async def get_tasks(
    status: Optional[str] = Query(None),
    department: Optional[str] = Query(None),
    priority: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    q = select(Task).order_by(Task.created_at.desc())

    # Rol asosida filter
    if credentials:
        payload = decode_token(credentials.credentials)
        if payload:
            user_id = payload.get("user_id")
            role = payload.get("role")
            if role == "employee":
                q = q.where(Task.assignee_id == user_id)
            elif role == "manager":
                user_result = await db.execute(select(User).where(User.id == user_id))
                user = user_result.scalar_one_or_none()
                if user and user.department_id:
                    q = q.where(Task.department_id == user.department_id)

    if status:
        q = q.where(Task.status == status)
    if department:
        q = q.where(Task.department == department)
    if priority:
        q = q.where(Task.priority == priority)

    result = await db.execute(q)
    tasks = result.scalars().all()
    return [await _task_to_out(t, db) for t in tasks]


@app.get("/api/tasks/my", response_model=list[TaskOut])
async def get_my_tasks(
    status: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Faqat menga berilgan vazifalar"""
    q = select(Task).where(Task.assignee_id == current_user.id).order_by(Task.created_at.desc())
    if status:
        q = q.where(Task.status == status)
    result = await db.execute(q)
    tasks = result.scalars().all()
    return [await _task_to_out(t, db) for t in tasks]


@app.post("/api/tasks", response_model=TaskOut)
async def create_task(
    body: TaskCreate,
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    created_by_id = None
    if credentials:
        payload = decode_token(credentials.credentials)
        if payload:
            created_by_id = payload.get("user_id")

    task = Task(
        title=body.title,
        description=body.description,
        department=body.department,
        department_id=body.department_id,
        priority=body.priority,
        status=body.status,
        source_document=body.source_document,
        deadline=body.deadline,
        assignee_id=body.assignee_id,
        created_by_id=created_by_id,
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)

    # Bildirishnoma yuborish
    if body.assignee_id:
        notif = Notification(
            user_id=body.assignee_id,
            title="Yangi vazifa berildi",
            body=f"Sizga yangi vazifa biriktirildi: {body.title}",
            type="task",
        )
        db.add(notif)
        await db.commit()

    return await _task_to_out(task, db)


@app.get("/api/tasks/{task_id}", response_model=TaskOut)
async def get_task(task_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Vazifa topilmadi")
    return await _task_to_out(task, db)


@app.patch("/api/tasks/{task_id}", response_model=TaskOut)
async def update_task(
    task_id: int,
    body: TaskUpdate,
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Vazifa topilmadi")

    old_assignee = task.assignee_id
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(task, k, v)
    task.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(task)

    # Yangi xodimga bildirishnoma
    if body.assignee_id and body.assignee_id != old_assignee:
        notif = Notification(
            user_id=body.assignee_id,
            title="Vazifa biriktirildi",
            body=f"Sizga vazifa biriktirildi: {task.title}",
            type="task",
        )
        db.add(notif)
        await db.commit()

    return await _task_to_out(task, db)


@app.patch("/api/tasks/{task_id}/status", response_model=TaskOut)
async def update_task_status(
    task_id: int,
    status: str = Query(...),
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Vazifa topilmadi")
    task.status = status
    task.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(task)

    # Yaratuvchiga bildirishnoma
    if task.created_by_id and status == "completed":
        notif = Notification(
            user_id=task.created_by_id,
            title="Vazifa bajarildi ✅",
            body=f"'{task.title}' vazifasi bajarildi.",
            type="success",
        )
        db.add(notif)
        await db.commit()

    return await _task_to_out(task, db)


@app.post("/api/tasks/{task_id}/assign", response_model=TaskOut)
async def assign_task(
    task_id: int,
    body: TaskAssign,
    current_user: User = Depends(require_manager_or_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Vazifa topilmadi")

    task.assignee_id = body.assignee_id
    task.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(task)

    # Bildirishnoma
    msg = body.message or f"Sizga '{task.title}' vazifasi biriktirildi."
    notif = Notification(
        user_id=body.assignee_id,
        title="Yangi vazifa",
        body=msg,
        type="task",
    )
    db.add(notif)
    await db.commit()

    return await _task_to_out(task, db)


@app.delete("/api/tasks/{task_id}")
async def delete_task(
    task_id: int,
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Vazifa topilmadi")
    await db.delete(task)
    await db.commit()
    return {"ok": True}


# ── Employees (eski — moslik uchun) ───────────────────────────────────────────
@app.get("/api/employees", response_model=list[EmployeeOut])
async def get_employees(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Employee).where(Employee.is_active == True).order_by(Employee.full_name)
    )
    return result.scalars().all()


@app.post("/api/employees", response_model=EmployeeOut)
async def create_employee(body: EmployeeCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(Employee).where(Employee.telegram_id == body.telegram_id))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Bu Telegram ID allaqachon ro'yxatdan o'tgan")
    emp = Employee(**body.model_dump())
    db.add(emp)
    await db.commit()
    await db.refresh(emp)
    return emp


@app.get("/api/employees/{telegram_id}", response_model=EmployeeOut)
async def get_employee(telegram_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
    emp = result.scalar_one_or_none()
    if not emp:
        raise HTTPException(404, "Xodim topilmadi")
    return emp


@app.patch("/api/employees/{telegram_id}", response_model=EmployeeOut)
async def update_employee(telegram_id: int, body: EmployeeUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
    emp = result.scalar_one_or_none()
    if not emp:
        raise HTTPException(404, "Xodim topilmadi")
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(emp, k, v)
    await db.commit()
    await db.refresh(emp)
    return emp


# ── Notifications ─────────────────────────────────────────────────────────────
@app.get("/api/notifications", response_model=list[NotificationOut])
async def get_my_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(50)
    )
    return result.scalars().all()


@app.get("/api/notifications/{telegram_id}", response_model=list[NotificationOut])
async def get_notifications(telegram_id: int, db: AsyncSession = Depends(get_db)):
    emp_result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
    emp = emp_result.scalar_one_or_none()
    if not emp:
        return []
    result = await db.execute(
        select(Notification)
        .where(Notification.employee_id == emp.id)
        .order_by(Notification.created_at.desc())
        .limit(50)
    )
    return result.scalars().all()


@app.patch("/api/notifications/{notif_id}/read")
async def mark_notification_read(notif_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Notification).where(Notification.id == notif_id))
    notif = result.scalar_one_or_none()
    if not notif:
        raise HTTPException(404, "Bildirishnoma topilmadi")
    notif.is_read = True
    await db.commit()
    return {"ok": True}


@app.patch("/api/notifications/read-all/me")
async def mark_all_read_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.is_read == False)
        .values(is_read=True)
    )
    await db.commit()
    return {"ok": True}


@app.patch("/api/notifications/read-all/{telegram_id}")
async def mark_all_read(telegram_id: int, db: AsyncSession = Depends(get_db)):
    emp_result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
    emp = emp_result.scalar_one_or_none()
    if not emp:
        raise HTTPException(404, "Xodim topilmadi")
    await db.execute(
        update(Notification)
        .where(Notification.employee_id == emp.id, Notification.is_read == False)
        .values(is_read=True)
    )
    await db.commit()
    return {"ok": True}


# ── Documents ─────────────────────────────────────────────────────────────────
@app.get("/api/documents", response_model=list[DocumentOut])
async def get_documents(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).order_by(Document.created_at.desc()))
    return result.scalars().all()


@app.post("/api/documents/upload", response_model=DocumentOut)
async def upload_document(
    file: UploadFile = File(...),
    telegram_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    allowed = {
        "application/pdf", "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "text/plain", "image/jpeg", "image/png",
    }
    if file.content_type not in allowed:
        raise HTTPException(400, "Fayl turi qo'llab-quvvatlanmaydi")

    ext = Path(file.filename or "file").suffix
    unique_name = f"{uuid.uuid4().hex}{ext}"
    file_path = UPLOAD_DIR / unique_name

    content = await file.read()
    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    content_text = None
    if file.content_type == "text/plain":
        try:
            content_text = content.decode("utf-8")[:5000]
        except Exception:
            pass

    uploaded_by_user = None
    if credentials:
        payload = decode_token(credentials.credentials)
        if payload:
            uploaded_by_user = payload.get("user_id")

    assignee_id = None
    if telegram_id:
        emp_result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
        emp = emp_result.scalar_one_or_none()
        if emp:
            assignee_id = emp.id

    doc = Document(
        filename=unique_name,
        original_name=file.filename or "unknown",
        file_path=str(file_path),
        file_type=file.content_type,
        file_size=len(content),
        content_text=content_text,
        uploaded_by=assignee_id,
        uploaded_by_user=uploaded_by_user,
    )
    db.add(doc)
    await db.commit()
    await db.refresh(doc)
    return doc


@app.delete("/api/documents/{doc_id}")
async def delete_document(doc_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == doc_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(404, "Hujjat topilmadi")
    try:
        Path(doc.file_path).unlink(missing_ok=True)
    except Exception:
        pass
    await db.delete(doc)
    await db.commit()
    return {"ok": True}


# ── Stats ─────────────────────────────────────────────────────────────────────
@app.get("/api/stats")
async def get_stats(
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    # Rol asosida filter
    task_query = select(func.count()).select_from(Task)
    pending_q = select(func.count()).select_from(Task).where(Task.status == "pending")
    in_progress_q = select(func.count()).select_from(Task).where(Task.status == "in_progress")
    completed_q = select(func.count()).select_from(Task).where(Task.status == "completed")

    if credentials:
        payload = decode_token(credentials.credentials)
        if payload:
            role = payload.get("role")
            user_id = payload.get("user_id")
            if role == "employee":
                task_query = task_query.where(Task.assignee_id == user_id)
                pending_q = pending_q.where(Task.assignee_id == user_id)
                in_progress_q = in_progress_q.where(Task.assignee_id == user_id)
                completed_q = completed_q.where(Task.assignee_id == user_id)
            elif role == "manager":
                user_result = await db.execute(select(User).where(User.id == user_id))
                user = user_result.scalar_one_or_none()
                if user and user.department_id:
                    task_query = task_query.where(Task.department_id == user.department_id)
                    pending_q = pending_q.where(Task.department_id == user.department_id)
                    in_progress_q = in_progress_q.where(Task.department_id == user.department_id)
                    completed_q = completed_q.where(Task.department_id == user.department_id)

    total_tasks = (await db.execute(task_query)).scalar()
    pending = (await db.execute(pending_q)).scalar()
    in_progress = (await db.execute(in_progress_q)).scalar()
    completed = (await db.execute(completed_q)).scalar()
    total_employees = (await db.execute(
        select(func.count()).select_from(User).where(User.is_active == True)
    )).scalar()
    total_docs = (await db.execute(select(func.count()).select_from(Document))).scalar()
    total_depts = (await db.execute(select(func.count()).select_from(Department))).scalar()

    return {
        "total_tasks": total_tasks,
        "pending": pending,
        "in_progress": in_progress,
        "completed": completed,
        "total_employees": total_employees,
        "total_documents": total_docs,
        "total_departments": total_depts,
    }


@app.get("/api/stats/departments")
async def get_department_stats(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(
            Task.department,
            func.count(Task.id).label("total"),
            func.sum(case((Task.status == "completed", 1), else_=0)).label("completed"),
            func.sum(case((Task.status == "in_progress", 1), else_=0)).label("in_progress"),
            func.sum(case((Task.status == "pending", 1), else_=0)).label("pending"),
        )
        .where(Task.department.isnot(None))
        .group_by(Task.department)
        .order_by(func.count(Task.id).desc())
    )
    rows = result.all()
    return [
        {
            "department": row.department,
            "total": row.total,
            "completed": row.completed or 0,
            "in_progress": row.in_progress or 0,
            "pending": row.pending or 0,
        }
        for row in rows
    ]
