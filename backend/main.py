from fastapi import FastAPI
from . import models, auth, files, notes, database

# Create database tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Brain Dump API")

app.include_router(auth.router)
app.include_router(files.router)
app.include_router(notes.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Brain Dump API"}
