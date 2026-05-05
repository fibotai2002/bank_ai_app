#!/bin/bash
# Tashkilot AI Backend - Ishga tushirish skripti

cd "$(dirname "$0")"

# Virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Virtual environment yaratilmoqda..."
    python3 -m venv venv
fi

source venv/bin/activate

# Paketlarni o'rnatish
echo "📥 Paketlar tekshirilmoqda..."
pip install -q -r requirements.txt
pip install -q greenlet

# Eski DB ni o'chirish (yangi schema uchun)
if [ "$1" == "--reset" ]; then
    echo "🗑️  Ma'lumotlar bazasi tozalanmoqda..."
    rm -f bank_ai.db
fi

echo ""
echo "🚀 Tashkilot AI Backend ishga tushmoqda..."
echo "📍 URL: http://localhost:8000"
echo "📖 Docs: http://localhost:8000/docs"
echo ""
echo "Demo hisoblar:"
echo "  👑 Admin:   admin / admin123"
echo "  🏢 Manager: manager1 / pass123"
echo "  👤 Xodim:   employee1 / pass123"
echo ""

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
