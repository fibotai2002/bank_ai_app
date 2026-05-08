from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from slowapi import Limiter
from slowapi.util import get_remote_address

from database import get_db, User, Department
from schemas import LoginRequest, LoginResponse, UserOut, UserUpdate
from auth import verify_password, create_access_token, hash_password, decode_token
from .common import get_current_user

limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/api/auth", tags=["Auth"])

@router.post("/login", response_model=LoginResponse)
@limiter.limit("10/minute")
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
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


@router.get("/me", response_model=UserOut)
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


@router.patch("/me", response_model=UserOut)
async def update_me(
    body: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump(exclude_none=True)

    # Parol o'zgartirish uchun eski parolni tekshirish
    if "password" in data:
        old_password = data.pop("old_password", None)
        if not old_password:
            raise HTTPException(
                status_code=400,
                detail="Parol o'zgartirish uchun eski parolni kiriting (old_password)"
            )
        if not verify_password(old_password, current_user.password_hash):
            raise HTTPException(status_code=400, detail="Eski parol noto'g'ri")
        current_user.password_hash = hash_password(data.pop("password"))
    else:
        data.pop("old_password", None)

    for k, v in data.items():
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
