from pydantic import BaseModel, Field, field_validator
from typing import Optional, Literal
from datetime import datetime
import re


# ── Auth ──────────────────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    username: str
    full_name: Optional[str] = None
    role: str
    department_id: Optional[int] = None
    department_name: Optional[str] = None


class UserOut(BaseModel):
    id: int
    username: str
    full_name: Optional[str] = None
    role: str
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    position: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserCreate(BaseModel):
    username: str
    password: str
    full_name: Optional[str] = None
    role: str = "employee"
    department_id: Optional[int] = None
    position: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    position: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    department_id: Optional[int] = None
    password: Optional[str] = None
    old_password: Optional[str] = None  # Parol o'zgartirish uchun eski parol


# ── Department ────────────────────────────────────────────────────────────────
class DepartmentCreate(BaseModel):
    name: str
    description: Optional[str] = None


class DepartmentOut(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    created_at: datetime
    user_count: Optional[int] = 0
    task_count: Optional[int] = 0

    class Config:
        from_attributes = True


# ── Task ──────────────────────────────────────────────────────────────────────
VALID_PRIORITIES = {"yuqori", "o'rta", "past"}
VALID_STATUSES = {"pending", "in_progress", "completed", "rejected"}
DEADLINE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=500)
    description: Optional[str] = Field(None, max_length=2000)
    department: Optional[str] = Field(None, max_length=200)
    department_id: Optional[int] = None
    priority: str = Field(default="o'rta")
    status: str = Field(default="pending")
    source_document: Optional[str] = Field(None, max_length=500)
    deadline: Optional[str] = None
    assignee_id: Optional[int] = None

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, v: str) -> str:
        if v not in VALID_PRIORITIES:
            raise ValueError(f"Priority '{v}' noto'g'ri. Qabul qilinadigan: {VALID_PRIORITIES}")
        return v

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in VALID_STATUSES:
            raise ValueError(f"Status '{v}' noto'g'ri. Qabul qilinadigan: {VALID_STATUSES}")
        return v

    @field_validator("deadline")
    @classmethod
    def validate_deadline(cls, v: Optional[str]) -> Optional[str]:
        if v and not DEADLINE_PATTERN.match(v):
            raise ValueError("Deadline formati noto'g'ri. YYYY-MM-DD formatida kiriting")
        return v


class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=500)
    description: Optional[str] = Field(None, max_length=2000)
    department: Optional[str] = Field(None, max_length=200)
    department_id: Optional[int] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    source_document: Optional[str] = Field(None, max_length=500)
    deadline: Optional[str] = None
    assignee_id: Optional[int] = None

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in VALID_PRIORITIES:
            raise ValueError(f"Priority '{v}' noto'g'ri. Qabul qilinadigan: {VALID_PRIORITIES}")
        return v

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in VALID_STATUSES:
            raise ValueError(f"Status '{v}' noto'g'ri. Qabul qilinadigan: {VALID_STATUSES}")
        return v

    @field_validator("deadline")
    @classmethod
    def validate_deadline(cls, v: Optional[str]) -> Optional[str]:
        if v and not DEADLINE_PATTERN.match(v):
            raise ValueError("Deadline formati noto'g'ri. YYYY-MM-DD formatida kiriting")
        return v


class TaskAssign(BaseModel):
    assignee_id: int
    message: Optional[str] = None


class TaskOut(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    department: Optional[str] = None
    department_id: Optional[int] = None
    priority: str
    status: str
    source_document: Optional[str] = None
    deadline: Optional[str] = None
    assignee_id: Optional[int] = None
    assignee_name: Optional[str] = None
    created_by_id: Optional[int] = None
    creator_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ── Chat ──────────────────────────────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str
    telegram_id: Optional[int] = None
    user_id: Optional[int] = None


class ChatResponse(BaseModel):
    answer: str
    task_title: Optional[str] = None
    responsible_department: Optional[str] = None
    priority: Optional[str] = None
    source_document: Optional[str] = None
    task_id: Optional[int] = None


# ── Employee (eski — moslik uchun) ────────────────────────────────────────────
class EmployeeCreate(BaseModel):
    telegram_id: int
    full_name: Optional[str] = None
    department: Optional[str] = None
    position: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None


class EmployeeUpdate(BaseModel):
    full_name: Optional[str] = None
    department: Optional[str] = None
    position: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None


class EmployeeOut(BaseModel):
    id: int
    telegram_id: int
    telegram_username: Optional[str] = None
    full_name: Optional[str] = None
    department: Optional[str] = None
    position: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ── Notification ──────────────────────────────────────────────────────────────
class NotificationOut(BaseModel):
    id: int
    title: str
    body: str
    type: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ── Document ──────────────────────────────────────────────────────────────────
class DocumentOut(BaseModel):
    id: int
    filename: str
    original_name: str
    file_type: Optional[str] = None
    file_size: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True
