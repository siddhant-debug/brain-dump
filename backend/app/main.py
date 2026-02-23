import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.core.limiter import limiter
from app.models import models
from app.api.routers import auth, files, notes, rag, analytics
from app.core import database
from app.services import rag_engine


# Create database tables
from sqlalchemy import text
with database.engine.begin() as conn:
    conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Brain Dump API")

# Attach rate limiter and register 429 handler
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.on_event("startup")
async def startup_event():
    print("Starting up... Loading RAG models.")
    rag_engine.initialize_models()

import logging
logger = logging.getLogger("api.cors")

@app.middleware("http")
async def log_requests(request: Request, call_next):
    origin = request.headers.get("origin", "unknown")
    logger.info(f"Incoming request from Origin: {origin} | Path: {request.url.path}")
    response = await call_next(request)
    return response

# Configure CORS
# Mobile app uses Bearer tokens — credentials (cookies) not needed
# allow_origins=["*"] is safe here since allow_credentials=False
# TODO: Whitelist origins after beta
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

app.include_router(auth.router)
app.include_router(files.router)
app.include_router(notes.router)
app.include_router(rag.router)
app.include_router(analytics.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Brain Dump API"}
