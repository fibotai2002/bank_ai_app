import os
import json
from google import genai
from google.genai import types
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, and_
from database import ChatHistory, Document, User, Department
from dotenv import load_dotenv

load_dotenv()

# Gemini API key
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None

GEMINI_MODEL = "gemini-1.5-flash"

SYSTEM_PROMPT = """Siz O'zbekiston Markaziy Banki Farg'ona viloyati boshqarmasining AI yordamchisisiz.

Vazifalaringiz:
1. Xodimlarning savollari va murojaatlariga o'zbek tilida professional javob berish.
2. Xabarlar yoki hujjatlar tarkibidagi topshiriqlarni aniqlash.
3. Aniqlangan topshiriqlarni eng mos bo'lim va xodimga taqsimlashni taklif qilish.
4. Bank tartib-qoidalari bo'yicha ma'lumot berish.

Javob berish qoidalari:
- Har doim o'zbek tilida javob bering.
- Professionallik va odob saqlang.
- Vazifa aniqlansa, uni JSON formatida taqdim eting.

Vazifa taqsimlashda quyidagilarga e'tibor bering:
- Vazifa mazmunidan kelib chiqib, eng mos bo'limni tanlang.
- Agar xodimlar ro'yxati berilgan bo'lsa, vazifani bajarishga eng munosib xodimni (lavozimidan kelib chiqib) taklif qiling.

JSON formati (faqat vazifa aniqlanganda):
{
  "answer": "Foydalanuvchiga javob matni",
  "task_title": "Vazifaning qisqa va aniq nomi",
  "responsible_department": "Bo'lim nomi",
  "suggested_employee_id": 123, // Xodim ID raqami (agar aniqlansa)
  "priority": "yuqori|o'rta|past",
  "deadline": "YYYY-MM-DD", // Agar xabarda sana bo'lsa
  "source_document": "Hujjat nomi"
}

Oddiy suhbat uchun:
{
  "answer": "Javob matni"
}
"""


async def get_chat_history(db: AsyncSession, telegram_id: int, limit: int = 10) -> list[dict]:
    result = await db.execute(
        select(ChatHistory)
        .where(ChatHistory.telegram_id == telegram_id)
        .order_by(desc(ChatHistory.created_at))
        .limit(limit)
    )
    rows = result.scalars().all()
    rows = list(reversed(rows))
    return [{"role": r.role, "content": r.content} for r in rows]


async def save_message(db: AsyncSession, telegram_id: int, role: str, content: str):
    msg = ChatHistory(telegram_id=telegram_id, role=role, content=content)
    db.add(msg)
    await db.commit()


async def get_documents_context(db: AsyncSession) -> str:
    result = await db.execute(
        select(Document).where(Document.content_text.isnot(None)).order_by(desc(Document.created_at)).limit(5)
    )
    docs = result.scalars().all()
    if not docs:
        return ""
    context = "\n\nOxirgi yuklangan hujjatlar:\n"
    for doc in docs:
        context += f"- {doc.original_name}: {(doc.content_text or '')[:500]}...\n"
    return context


async def get_employees_context(db: AsyncSession) -> str:
    result = await db.execute(
        select(User, Department.name)
        .join(Department, User.department_id == Department.id, isouter=True)
        .where(User.is_active == True)
    )
    rows = result.all()
    if not rows:
        return ""
    
    context = "\n\nTashkilot xodimlari va bo'limlari:\n"
    for user, dept_name in rows:
        context += f"- ID: {user.id}, Ism: {user.full_name}, Bo'lim: {dept_name or 'Noma`lum'}, Lavozim: {user.position or 'Xodim'}\n"
    return context


async def chat_with_ai(
    db: AsyncSession,
    message: str,
    telegram_id: int
) -> dict:
    # Tarix olish
    history = await get_chat_history(db, telegram_id)

    # Hujjatlar konteksti
    doc_context = await get_documents_context(db)
    
    # Xodimlar konteksti
    emp_context = await get_employees_context(db)

    # Promptni tayyorlash
    system = SYSTEM_PROMPT
    if doc_context:
        system += doc_context
    if emp_context:
        system += emp_context

    # Tarixni matnga birlashtirish
    history_text = ""
    for h in history:
        if h["role"] == "user":
            history_text += f"Foydalanuvchi: {h['content']}\n"
        else:
            history_text += f"AI: {h['content']}\n"

    full_prompt = f"{system}\n\n{history_text}\nFoydalanuvchi: {message}\nAI:"

    result = {}
    try:
        if client is None:
            raise RuntimeError("GEMINI_API_KEY is not set")
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=full_prompt,
            config=types.GenerateContentConfig(
                temperature=0.3,
                max_output_tokens=1000,
                response_mime_type="application/json",
            ),
        )
        content = response.text or "{}"
        result = json.loads(content)
    except Exception as e:
        print(f"Gemini xatosi: {e}")
        result = _demo_response(message)

    # Tarixga saqlash
    await save_message(db, telegram_id, "user", message)
    await save_message(db, telegram_id, "assistant", result.get("answer", ""))

    return result


def _demo_response(message: str) -> dict:
    """Gemini API ishlamasa demo javoblar"""
    msg_lower = message.lower()

    if any(w in msg_lower for w in ["vazifa", "topshiriq", "bajar", "hujjat"]):
        return {
            "answer": f"'{message}' bo'yicha vazifa aniqlandi va tegishli bo'limga yo'naltirildi.",
            "task_title": message[:100],
            "responsible_department": "Nazorat bo'limi",
            "priority": "o'rta",
            "source_document": ""
        }
    elif any(w in msg_lower for w in ["kredit", "qarz", "foiz"]):
        return {
            "answer": "Kredit bo'yicha ma'lumot: Markaziy Bank belgilagan stavkalar asosida kreditlar beriladi. "
                      "Batafsil ma'lumot uchun Kredit bo'limiga murojaat qiling."
        }
    elif any(w in msg_lower for w in ["salom", "assalom", "xayr", "rahmat"]):
        return {
            "answer": "Assalomu alaykum! Men Markaziy Bank AI yordamchisiman. "
                      "Sizga qanday yordam bera olaman?"
        }
    else:
        return {
            "answer": f"Savolingiz qabul qilindi. '{message}' bo'yicha ma'lumot tayyorlanmoqda. "
                      "Iltimos, aniqroq savol bering yoki tegishli bo'lim bilan bog'laning."
        }
