# BrainDump Deployment Guide

## 1. Prerequisites
- **Server**: Ubuntu 22.04+ recommended.
- **Hardware**: GPU optional but recommended for faster reranking; minimum 8GB RAM.
- **Internal Stack**: Docker (optional), Python 3.13, PostgreSQL 14+ with `pgvector` extension.

## 2. Server Setup (Ubuntu)

### Install Core Dependencies
```bash
sudo apt update
sudo apt install python3-pip python3-venv postgresql postgresql-contrib libpq-dev
```

### Configure PostgreSQL with pgvector
Ensure the `pgvector` extension is installed and enabled on your database:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

## 3. Backend Deployment

### Initial Clone & Venv
```bash
git clone <repo-url>
cd brain-dump/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Environment Variables
Create a `.env` file in `backend/app/`:
```env
DATABASE_URL=postgresql://user:pass@localhost/braindump
GEMINI_API_KEY=your_api_key_here
JWT_SECRET_KEY=your_secure_random_string
APPLE_MUSIC_JWT=your_musickit_jwt
```

### Database Migrations
Always run migrations before starting the server:
```bash
alembic upgrade head
```

### Service Configuration (Systemd)
Create `/etc/systemd/system/braindump.service`:
```ini
[Unit]
Description=BrainDump FastAPI Backend
After=network.target

[Service]
User=sidtom
WorkingDirectory=/home/sidtom/application/projects/brain-dump/backend
Environment="PATH=/home/sidtom/application/projects/brain-dump/backend/venv/bin"
ExecStart=/home/sidtom/application/projects/brain-dump/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4

[Install]
WantedBy=multi-user.target
```

## 4. Frontend Deployment
The iOS application is distributed via TestFlight. 
- Ensure `.env` is bundled using `flutter_dotenv`.
- Set the `ApiConstants.baseUrl` to your server's public IP/Domain.

## 5. Maintenance
- **Logs**: `journalctl -u braindump -f`
- **Reindexing**: Run `python scripts/reindex_rag.py` if embedding models are changed.
- **SSL**: Highly recommended to use Nginx with Certbot (Let's Encrypt) to proxy the FastAPI traffic.
