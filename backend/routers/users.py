from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List

from database import get_db, User, Department, Task
from schemas import UserOut, UserCreate, DepartmentOut, DepartmentCreate
from auth import hash_password
from .common import require_admin, require_manager_or_admin, get_current_user

router = APIRouter(prefix="/api", tags=["Users & Departments"])

@router.get("/users", response_model=List[UserOut])
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


@router.post("/users", response_model=UserOut)
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


@router.delete("/users/{user_id}")
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


@router.get("/departments", response_model=List[DepartmentOut])
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


@router.post("/departments", response_model=DepartmentOut)
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
