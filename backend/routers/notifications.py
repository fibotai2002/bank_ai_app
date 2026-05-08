from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from typing import List

from database import get_db, Notification, User, Employee
from schemas import NotificationOut
from .common import get_current_user

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])

@router.get("", response_model=List[NotificationOut])
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


@router.get("/{telegram_id}", response_model=List[NotificationOut])
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


@router.patch("/{notif_id}/read")
async def mark_notification_read(notif_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Notification).where(Notification.id == notif_id))
    notif = result.scalar_one_or_none()
    if not notif:
        raise HTTPException(404, "Bildirishnoma topilmadi")
    notif.is_read = True
    await db.commit()
    return {"ok": True}


@router.patch("/read-all/me")
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


@router.patch("/read-all/{telegram_id}")
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
