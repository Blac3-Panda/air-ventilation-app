# Air Guide Backend (FastAPI)

## 1) Setup

```powershell
cd C:\Users\heeso\Desktop\air_guide_app\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Edit `.env` and set:

```env
DATA_GO_KR_SERVICE_KEY=...
```

## 2) Run

```powershell
uvicorn app.main:app --reload --port 8000
```

## 3) Check endpoints

- http://127.0.0.1:8000/health
- http://127.0.0.1:8000/air/current?sidoName=서울
- http://127.0.0.1:8000/weather/current?nx=60&ny=127
- http://127.0.0.1:8000/tms/current
- http://127.0.0.1:8000/building/title?sigunguCd=11680&bjdongCd=10300&bun=0001&ji=0000
- http://127.0.0.1:8000/status/summary?sidoName=서울&nx=60&ny=127
