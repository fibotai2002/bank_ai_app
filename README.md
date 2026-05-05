# 🏦 Markaziy Bank AI — Flutter + FastAPI

**O'zbekiston Markaziy Banki Farg'ona viloyati boshqarmasi** uchun AI yordamchi ilova.

---

## 📱 Ilova imkoniyatlari

| Ekran | Funksiya |
|-------|----------|
| 🤖 **Chat** | AI bilan suhbat, vazifa aniqlash, hujjat yuklash |
| ✅ **Vazifalar** | Vazifalar ro'yxati, filter, status o'zgartirish, deadline |
| 👥 **Xodimlar** | Bo'limlar bo'yicha guruh, qidiruv, detail ko'rish |
| 🔔 **Bildirishnomalar** | O'qilmagan xabarlar, badge |
| 👤 **Profil** | Ma'lumotlarni tahrirlash, statistika, chiqish |

---

## 🗂️ Loyiha tuzilmasi

```
bank_ai_app/
├── backend/                  # FastAPI server
│   ├── main.py               # API endpoints
│   ├── database.py           # SQLAlchemy modellari
│   ├── schemas.py            # Pydantic schemalar
│   ├── ai_agent.py           # OpenAI GPT-4o-mini agent
│   ├── requirements.txt      # Python paketlar
│   ├── start.sh              # Ishga tushirish skripti
│   └── .env.example          # Environment o'zgaruvchilar
│
└── lib/                      # Flutter ilova
    ├── main.dart             # App entry point, HomeScreen (5 tab)
    ├── core/
    │   ├── api/api_client.dart    # Dio HTTP client
    │   └── theme/app_theme.dart   # Light/Dark tema
    └── features/
        ├── auth/login_screen.dart
        ├── chat/chat_screen.dart
        ├── tasks/tasks_screen.dart
        ├── employees/employees_screen.dart
        ├── notifications/notifications_screen.dart
        └── profile/profile_screen.dart
```

---

## 🚀 Ishga tushirish

### 1. Backend (FastAPI)

```bash
cd backend

# Ishga tushirish (avtomatik venv yaratadi)
chmod +x start.sh
./start.sh
```

Yoki qo'lda:
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# .env faylida OPENAI_API_KEY ni kiriting
uvicorn main:app --reload --port 8000
```

**API docs:** http://localhost:8000/docs

### 2. Flutter ilovasi

```bash
# Paketlarni o'rnatish
flutter pub get

# Android emulyatorda ishga tushirish
flutter run

# iOS simulatorda
flutter run -d ios
```

> **Muhim:** `lib/core/api/api_client.dart` da `baseUrl` ni to'g'ri sozlang:
> - Android emulyator: `http://10.0.2.2:8000`
> - iOS simulator: `http://localhost:8000`
> - Real qurilma: `http://YOUR_SERVER_IP:8000`

---

## ⚙️ Environment (.env)

```env
OPENAI_API_KEY=sk-your-openai-key-here
DATABASE_URL=sqlite+aiosqlite:///./bank_ai.db
SECRET_KEY=your-secret-key-here
```

> OpenAI API kaliti bo'lmasa ham ilova ishlaydi — demo javoblar qaytaradi.

---

## 🔌 API Endpoints

| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/chat` | AI bilan suhbat |
| GET | `/api/tasks` | Vazifalar ro'yxati |
| POST | `/api/tasks` | Yangi vazifa |
| PATCH | `/api/tasks/{id}/status` | Status o'zgartirish |
| DELETE | `/api/tasks/{id}` | Vazifani o'chirish |
| GET | `/api/employees` | Xodimlar ro'yxati |
| GET | `/api/employees/{telegram_id}` | Xodim ma'lumoti |
| PATCH | `/api/employees/{telegram_id}` | Xodimni yangilash |
| GET | `/api/notifications/{telegram_id}` | Bildirishnomalar |
| POST | `/api/documents/upload` | Hujjat yuklash |
| GET | `/api/stats` | Statistika |

---

## 📦 Texnologiyalar

**Backend:**
- FastAPI + Uvicorn
- SQLAlchemy (async) + SQLite
- OpenAI GPT-4o-mini
- Pydantic v2

**Frontend:**
- Flutter 3.x
- Dio (HTTP)
- SharedPreferences
- FilePicker
- Intl

---

## 👨‍💻 Ishlab chiquvchi

**Bank Farg'ona** — Markaziy Bank AI loyihasi, 2026
