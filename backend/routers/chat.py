from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from typing import Optional
from fastapi.security import HTTPAuthorizationCredentials
from slowapi import Limiter
from slowapi.util import get_remote_address

import uuid
import aiofiles
from pathlib import Path
from fastapi import UploadFile, File, Form
from database import get_db, Employee, Department, User, Task, Notification
from schemas import ChatRequest, ChatResponse
from auth import decode_token
from ai_agent import chat_with_ai, chat_audio_with_ai
from .common import security
from .ws import manager

limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/api/chat", tags=["Chat"])

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

@router.post("", response_model=ChatResponse)
@limiter.limit("30/minute")
async def chat(
    request: Request,
    req: ChatRequest,
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    user_id = req.user_id
    telegram_id = req.telegram_id
    role = None

    # Token orqali user_id aniqlash
    if credentials:
        payload = decode_token(credentials.credentials)
        if payload:
            user_id = payload.get("user_id")
            role = payload.get("role")

    # Eski telegram_id bilan moslik
    if not user_id and telegram_id:
        emp_result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
        emp = emp_result.scalar_one_or_none()
        if not emp:
            emp = Employee(telegram_id=telegram_id)
            db.add(emp)
            await db.commit()

    result = await chat_with_ai(db, req.message, telegram_id or 0)

    # Agar vazifa aniqlansa - DBga saqlash va xodimga biriktirish
    if result.get("task_title"):
        dept_name = (result.get("responsible_department") or "").strip() or None

        dept_id = None
        if dept_name:
            dept_r = await db.execute(select(Department).where(Department.name == dept_name))
            dept = dept_r.scalar_one_or_none()
            dept_id = dept.id if dept else None

        assignee_id = result.get("suggested_employee_id")
        
        if not assignee_id and dept_id:
            # Eng kam pending vazifasi bor employee tanlash
            emp_r = await db.execute(
                select(User)
                .where(
                    and_(
                        User.is_active == True,
                        User.role == "employee",
                        User.department_id == dept_id,
                    )
                )
                .order_by(User.id.asc())
            )
            employees = emp_r.scalars().all()
            if employees:
                # pending countlar
                from sqlalchemy import func
                counts_r = await db.execute(
                    select(Task.assignee_id, func.count(Task.id))
                    .where(and_(Task.status == "pending", Task.assignee_id.in_([e.id for e in employees])))
                    .group_by(Task.assignee_id)
                )
                counts = {row[0]: row[1] for row in counts_r.all()}
                employees.sort(key=lambda u: (counts.get(u.id, 0), u.id))
                assignee_id = employees[0].id

        task = Task(
            title=result["task_title"],
            description=result.get("answer"), # AI javobini tavsif sifatida saqlash
            department=dept_name,
            department_id=dept_id,
            priority=result.get("priority", "o'rta"),
            source_document=result.get("source_document"),
            deadline=result.get("deadline"),
            status="pending",
            assignee_id=assignee_id,
            created_by_id=user_id,
        )
        db.add(task)
        await db.commit()
        await db.refresh(task)
        result["task_id"] = task.id

        if assignee_id:
            notif = Notification(
                user_id=assignee_id,
                title="Yangi vazifa",
                body=f"Sizga vazifa biriktirildi: {task.title}",
                type="task",
            )
            db.add(notif)
            await db.commit()
            
            # Real-time bildirishnoma
            await manager.send_personal_message({
                "type": "notification",
                "title": "Yangi vazifa",
                "body": f"Sizga vazifa biriktirildi: {task.title}",
                "task_id": task.id
            }, assignee_id)

    return ChatResponse(**result)


@router.post("/audio", response_model=ChatResponse)
@limiter.limit("15/minute")
async def chat_audio(
    request: Request,
    file: UploadFile = File(...),
    telegram_id: Optional[int] = Form(None),
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    user_id = None
    if credentials:
        payload = decode_token(credentials.credentials)
        if payload:
            user_id = payload.get("user_id")

    if not user_id and telegram_id:
        emp_result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
        emp = emp_result.scalar_one_or_none()
        if not emp:
            emp = Employee(telegram_id=telegram_id)
            db.add(emp)
            await db.commit()

    # Faylni saqlab olish
    ext = Path(file.filename or "audio").suffix
    if not ext:
        ext = ".aac"
    unique_name = f"audio_{uuid.uuid4().hex}{ext}"
    file_path = UPLOAD_DIR / unique_name

    content = await file.read()
    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    # Audio faylni Gemini bilan tahlil qilish
    result = await chat_audio_with_ai(db, str(file_path), telegram_id or 0)

    # Agar vazifa aniqlansa - DBga saqlash va xodimga biriktirish
    if result.get("task_title"):
        dept_name = (result.get("responsible_department") or "").strip() or None

        dept_id = None
        if dept_name:
            dept_r = await db.execute(select(Department).where(Department.name == dept_name))
            dept = dept_r.scalar_one_or_none()
            dept_id = dept.id if dept else None

        assignee_id = result.get("suggested_employee_id")
        
        if not assignee_id and dept_id:
            emp_r = await db.execute(
                select(User)
                .where(
                    and_(
                        User.is_active == True,
                        User.role == "employee",
                        User.department_id == dept_id,
                    )
                )
                .order_by(User.id.asc())
            )
            employees = emp_r.scalars().all()
            if employees:
                from sqlalchemy import func
                counts_r = await db.execute(
                    select(Task.assignee_id, func.count(Task.id))
                    .where(and_(Task.status == "pending", Task.assignee_id.in_([e.id for e in employees])))
                    .group_by(Task.assignee_id)
                )
                counts = {row[0]: row[1] for row in counts_r.all()}
                employees.sort(key=lambda u: (counts.get(u.id, 0), u.id))
                assignee_id = employees[0].id

        task = Task(
            title=result["task_title"],
            description=result.get("answer"),
            department=dept_name,
            department_id=dept_id,
            priority=result.get("priority", "o'rta"),
            source_document=result.get("source_document"),
            deadline=result.get("deadline"),
            status="pending",
            assignee_id=assignee_id,
            created_by_id=user_id,
        )
        db.add(task)
        await db.commit()
        await db.refresh(task)
        result["task_id"] = task.id

        if assignee_id:
            notif = Notification(
                user_id=assignee_id,
                title="Yangi vazifa",
                body=f"Sizga ovozli xabar orqali vazifa biriktirildi: {task.title}",
                type="task",
            )
            db.add(notif)
            await db.commit()
            
            await manager.send_personal_message({
                "type": "notification",
                "title": "Yangi vazifa",
                "body": f"Sizga vazifa biriktirildi: {task.title}",
                "task_id": task.id
            }, assignee_id)

    # Ixtiyoriy ravishda faylni o'chirish mumkin, yoki qoldirish
    try:
        Path(file_path).unlink(missing_ok=True)
    except:
        pass

    return ChatResponse(**result)
