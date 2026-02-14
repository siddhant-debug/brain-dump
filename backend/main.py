from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from . import models, auth, files, notes, database

# Create database tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Brain Dump API")

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

@app.get("/")
def read_root():
    return {"message": "Welcome to Brain Dump API"}
