from pydantic import BaseModel, EmailStr
from typing import Optional, List
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

class LocationContext(BaseModel):
    latitude: float
    longitude: float
    city: Optional[str] = None
    country: Optional[str] = None
    location_type: Optional[str] = None # home, cafe, gym, office, outdoor

class NoteCreate(BaseModel):
    content: str
    location: Optional[LocationContext] = None

class NoteResponse(BaseModel):
    id: int
    content: str
    is_favorite: bool
    created_at: datetime

    class Config:
        from_attributes = True

class ChatRequest(BaseModel):
    query: str
    location: Optional[LocationContext] = None

class ChatResponse(BaseModel):
    answer: str
    sources: List[str]

class StoredFileResponse(BaseModel):
    id: int
    filename: str
    created_at: datetime

    class Config:
        from_attributes = True

class ChatMessageResponse(BaseModel):
    id: int
    content: str
    sender: str
    timestamp: datetime
    context_sources: Optional[str] = None

    class Config:
        from_attributes = True