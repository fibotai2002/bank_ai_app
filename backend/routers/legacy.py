from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from database import get_db, Employee
from schemas import EmployeeCreate, EmployeeUpdate, EmployeeOut

router = APIRouter(prefix="/api/employees", tags=["Legacy Employees"])

@router.get("", response_model=List[EmployeeOut])
async def get_employees(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Employee).where(Employee.is_active == True).order_by(Employee.full_name)
    )
    return result.scalars().all()


@router.post("", response_model=EmployeeOut)
async def create_employee(body: EmployeeCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(Employee).where(Employee.telegram_id == body.telegram_id))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Bu Telegram ID allaqachon ro'yxatdan o'tgan")
    emp = Employee(**body.model_dump())
    db.add(emp)
    await db.commit()
    await db.refresh(emp)
    return emp


@router.get("/{telegram_id}", response_model=EmployeeOut)
async def get_employee(telegram_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Employee).where(Employee.telegram_id == telegram_id))
    emp = result.scalar_one_or_none()
    if not emp:
        raise HTTPException(404, "Xodim topilmadi")
    return emp


@router.patch("/{telegram_id}", response_model=EmployeeOut)
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
