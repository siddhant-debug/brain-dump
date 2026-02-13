from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    profile_pic: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(UserBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class FileResponseSchema(BaseModel):
    id: int
    filename: str
    file_type: str
    file_size: int
    created_at: datetime

    class Config:
        from_attributes = True

class NoteCreate(BaseModel):
    content: str

class NoteResponse(BaseModel):
    id: int
    content: str
    is_favorite: bool
    created_at: datetime

    class Config:
        from_attributes = True
