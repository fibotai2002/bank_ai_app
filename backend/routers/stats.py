from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, case
from typing import Optional, List
from fastapi.security import HTTPAuthorizationCredentials

from database import get_db, Task, User, Document, Department
from auth import decode_token
from .common import security

router = APIRouter(prefix="/api/stats", tags=["Stats"])

@router.get("")
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


@router.get("/departments")
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
