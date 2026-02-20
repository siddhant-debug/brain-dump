from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.models import models
from app.api.routers import auth, files, notes, rag
from app.core import database
from app.services import rag_engine

# Create database tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Brain Dump API")

@app.on_event("startup")
async def startup_event():
    print("Starting up... Loading RAG models.")
    rag_engine.initialize_models()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(files.router)
app.include_router(notes.router)
app.include_router(rag.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Brain Dump API"}
