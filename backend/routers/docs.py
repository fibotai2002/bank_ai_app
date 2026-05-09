import uuid
import aiofiles
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional, List
from fastapi.security import HTTPAuthorizationCredentials

from database import get_db, Document, Employee
from schemas import DocumentOut
from auth import decode_token
from .common import security

router = APIRouter(prefix="/api/documents", tags=["Documents"])

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

@router.get("", response_model=List[DocumentOut])
async def get_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Document).order_by(Document.created_at.desc()).offset(skip).limit(limit))
    return result.scalars().all()


@router.post("/upload", response_model=DocumentOut)
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


@router.delete("/{doc_id}")
async def delete_document(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    # Auth tekshirish
    if not credentials:
        raise HTTPException(status_code=401, detail="Token taqdim etilmagan")
    payload = decode_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Token yaroqsiz yoki muddati o'tgan")

    current_user_id = payload.get("user_id")
    current_role = payload.get("role")

    result = await db.execute(select(Document).where(Document.id == doc_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(404, "Hujjat topilmadi")

    # Faqat admin yoki hujjatni yuklagan kishi o'chira oladi
    if current_role != "admin" and doc.uploaded_by_user != current_user_id:
        raise HTTPException(403, "Bu hujjatni o'chirish huquqingiz yo'q")

    try:
        Path(doc.file_path).unlink(missing_ok=True)
    except Exception:
        pass
    await db.delete(doc)
    await db.commit()
    return {"ok": True}
