import os
import json
from google import genai
from google.genai import types
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from database import ChatHistory, Task, Employee, Document
from dotenv import load_dotenv

load_dotenv()

# Gemini API key
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
client = genai.Client(api_key=GEMINI_API_KEY)

GEMINI_MODEL = "gemini-1.5-flash"

SYSTEM_PROMPT = """Siz O'zbekiston Markaziy Banki Farg'ona viloyati boshqarmasining AI yordamchisisiz.

Vazifalaringiz:
1. Xodimlarning savollariga javob berish
2. Hujjatlardan vazifalarni aniqlash va taqsimlash
3. Bank qoidalari va tartib-qoidalari haqida ma'lumot berish
4. Vazifalarni tegishli bo'limlarga yo'naltirish

Javob berish qoidalari:
- Har doim o'zbek tilida javob bering
- Aniq va qisqa javob bering
- Agar vazifa aniqlansa, JSON formatida qaytaring
- Professionallik saqlang

Agar foydalanuvchi biror vazifa yoki topshiriq haqida so'rasa yoki hujjat tahlil qilishni so'rasa,
quyidagi JSON formatida javob bering (faqat vazifa aniqlanganda):

{
  "answer": "Javob matni",
  "task_title": "Vazifa nomi",
  "responsible_department": "Mas'ul bo'lim",
  "priority": "yuqori|o'rta|past",
  "source_document": "Hujjat nomi (agar mavjud bo'lsa)"
}

Agar oddiy savol bo'lsa, faqat:
{
  "answer": "Javob matni"
}

Bo'limlar ro'yxati:
- Kredit bo'limi
- Hisob-kitob bo'limi
- Nazorat bo'limi
- Kadrlar bo'limi
- Moliya bo'limi
- Yuridik bo'lim
- IT bo'limi
- Xavfsizlik bo'limi
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
        select(Document).where(Document.content_text.isnot(None)).limit(5)
    )
    docs = result.scalars().all()
    if not docs:
        return ""
    context = "\n\nMavjud hujjatlar:\n"
    for doc in docs:
        context += f"- {doc.original_name}: {(doc.content_text or '')[:500]}...\n"
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

    # Promptni tayyorlash
    system = SYSTEM_PROMPT
    if doc_context:
        system += doc_context

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

    # Agar vazifa aniqlansa - DBga saqlash
    if result.get("task_title"):
        task = Task(
            title=result["task_title"],
            department=result.get("responsible_department"),
            priority=result.get("priority", "o'rta"),
            source_document=result.get("source_document"),
            status="pending",
        )
        db.add(task)
        await db.commit()
        await db.refresh(task)
        result["task_id"] = task.id

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
