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
│   ├── main.py               # App entry point, middleware
│   ├── database.py           # SQLAlchemy modellari
│   ├── schemas.py            # Pydantic schemalar
│   ├── auth.py               # JWT autentifikatsiya
│   ├── ai_agent.py           # Gemini AI agent
│   ├── requirements.txt      # Python paketlar (versiyalar pinlangan)
│   ├── runtime.txt           # Python versiyasi
│   ├── Procfile              # Render/Heroku uchun
│   ├── render.yaml           # Render deploy konfiguratsiyasi
│   └── routers/
│       ├── auth.py           # Login, /me (rate limited)
│       ├── tasks.py          # Vazifalar CRUD
│       ├── users.py          # Foydalanuvchilar
│       ├── chat.py           # AI chat (rate limited)
│       ├── docs.py           # Hujjatlar
│       ├── notifications.py  # Bildirishnomalar
│       ├── stats.py          # Statistika
│       ├── ws.py             # WebSocket (authenticated)
│       └── legacy.py         # Eski Employee API
│
└── lib/                      # Flutter ilova
    ├── main.dart             # App entry point, HomeScreen (7 tab)
    ├── core/
    │   ├── api/api_client.dart    # Dio HTTP client
    │   └── theme/app_theme.dart   # Light/Dark tema
    └── features/
        ├── auth/login_screen.dart
        ├── dashboard/dashboard_screen.dart
        ├── chat/chat_screen.dart
        ├── tasks/tasks_screen.dart
        ├── employees/employees_screen.dart
        ├── documents/documents_screen.dart
        ├── notifications/notifications_screen.dart
        └── profile/profile_screen.dart
```

---

## 🚀 Development — Ishga tushirish

### 1. Backend (FastAPI)

```bash
cd backend

# .env fayl yaratish
cp .env.example .env
# .env faylida GEMINI_API_KEY va SECRET_KEY ni kiriting

# Virtual environment va paketlar
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Ishga tushirish
uvicorn main:app --reload --port 8000
```

**API docs:** http://localhost:8000/docs

### 2. Flutter ilovasi

```bash
# Paketlarni o'rnatish
flutter pub get

# Android emulyatorda (default URL: http://10.0.2.2:8000)
flutter run

# iOS simulatorda (default URL: http://localhost:8000)
flutter run -d ios

# Maxsus server URL bilan
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

---

## 🏭 Production — Deploy

### Backend (Render.com)

1. GitHub ga push qiling
2. Render.com da yangi **Web Service** yarating
3. `render.yaml` avtomatik konfiguratsiya qiladi
4. **Environment Variables** ni sozlang:

| Variable | Qiymat |
|----------|--------|
| `SECRET_KEY` | `openssl rand -hex 32` bilan yarating |
| `DATABASE_URL` | PostgreSQL URL (Neon/Supabase/Render Postgres) |
| `GEMINI_API_KEY` | Google AI Studio dan oling |
| `CORS_ORIGINS` | `https://your-domain.com` yoki `*` |
| `ENVIRONMENT` | `production` |

> ⚠️ **Muhim:** Production da SQLite ishlatmang! PostgreSQL ulang.
> Production da `/docs` va `/redoc` avtomatik o'chiriladi.

### Flutter — Production Build

```bash
# Android APK
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-api.onrender.com

# Android App Bundle (Play Store uchun)
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-api.onrender.com

# iOS
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-api.onrender.com

# Web
flutter build web --release \
  --dart-define=API_BASE_URL=https://your-api.onrender.com
```

---

## ⚙️ Environment (.env)

```env
# Majburiy
GEMINI_API_KEY=your-gemini-api-key-here
SECRET_KEY=your-very-secret-key-change-this-in-production

# Ma'lumotlar bazasi
DATABASE_URL=sqlite+aiosqlite:///./bank_ai.db
# Production: DATABASE_URL=postgresql://user:pass@host:5432/dbname

# CORS
CORS_ORIGINS=*
# Production: CORS_ORIGINS=https://your-app.com

# Muhit
ENVIRONMENT=development
# Production: ENVIRONMENT=production
```

---

## 🔌 API Endpoints

| Method | URL | Tavsif | Auth |
|--------|-----|--------|------|
| POST | `/api/auth/login` | Login (10/min limit) | ❌ |
| GET | `/api/auth/me` | Joriy foydalanuvchi | ✅ |
| PATCH | `/api/auth/me` | Profilni yangilash | ✅ |
| GET | `/api/tasks` | Vazifalar ro'yxati | Optional |
| POST | `/api/tasks` | Yangi vazifa | Optional |
| PATCH | `/api/tasks/{id}/status` | Status o'zgartirish | Optional |
| DELETE | `/api/tasks/{id}` | Vazifani o'chirish | ✅ |
| GET | `/api/users` | Foydalanuvchilar | ✅ Manager+ |
| POST | `/api/users` | Yangi foydalanuvchi | ✅ Admin |
| GET | `/api/departments` | Bo'limlar | ✅ |
| POST | `/api/chat` | AI chat (30/min limit) | Optional |
| GET | `/api/documents` | Hujjatlar | ❌ |
| POST | `/api/documents/upload` | Hujjat yuklash | Optional |
| DELETE | `/api/documents/{id}` | Hujjat o'chirish | ✅ |
| GET | `/api/notifications` | Bildirishnomalar | ✅ |
| GET | `/api/stats` | Statistika | Optional |
| WS | `/ws/{user_id}?token=...` | WebSocket | ✅ Token |
| GET | `/health` | Health check (DB) | ❌ |

---

## 🔐 Xavfsizlik

- **JWT** token autentifikatsiya (7 kun)
- **bcrypt** parol hashing
- **Rate limiting:** Login 10/min, Chat 30/min, Global 200/min
- **Role-based access:** admin, manager, employee
- **WebSocket** token autentifikatsiya
- **Production** da `/docs` o'chiriladi

---

## 📦 Texnologiyalar

**Backend:**
- FastAPI 0.115.6 + Uvicorn 0.32.1
- SQLAlchemy 2.0.36 (async) + SQLite/PostgreSQL
- Google Gemini AI (gemini-1.5-flash)
- Pydantic 2.10.3
- slowapi (rate limiting)
- PyJWT + passlib[bcrypt]

**Frontend:**
- Flutter 3.x
- Dio (HTTP client)
- SharedPreferences
- FilePicker
- web_socket_channel

---

## 👨‍💻 Demo hisoblar

| Role | Username | Parol |
|------|----------|-------|
| 👑 Admin | `admin` | `admin123` |
| 🏢 Manager | `manager1` | `pass123` |
| 👤 Xodim | `employee1` | `pass123` |

> ⚠️ Production da demo parollarni o'zgartiring!

---

## 👨‍💻 Ishlab chiquvchi

**Bank Farg'ona** — Markaziy Bank AI loyihasi, 2026
