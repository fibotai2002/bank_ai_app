from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from typing import Optional
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from database import get_db, Task, User, Notification
from schemas import TaskCreate, TaskUpdate, TaskOut, TaskAssign
from auth import decode_token
from .common import get_current_user, require_manager_or_admin, security

router = APIRouter(prefix="/api/tasks", tags=["Tasks"])

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


@router.get("", response_model=list[TaskOut])
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


@router.get("/my", response_model=list[TaskOut])
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


@router.post("", response_model=TaskOut)
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


@router.get("/{task_id}", response_model=TaskOut)
async def get_task(task_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Vazifa topilmadi")
    return await _task_to_out(task, db)


@router.patch("/{task_id}", response_model=TaskOut)
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


@router.patch("/{task_id}/status", response_model=TaskOut)
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


@router.post("/{task_id}/assign", response_model=TaskOut)
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


@router.delete("/{task_id}")
async def delete_task(
    task_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Vazifa topilmadi")

    # Faqat admin yoki vazifani yaratgan kishi o'chira oladi
    if current_user.role != "admin" and task.created_by_id != current_user.id:
        raise HTTPException(403, "Bu vazifani o'chirish huquqingiz yo'q")

    await db.delete(task)
    await db.commit()
    return {"ok": True}
