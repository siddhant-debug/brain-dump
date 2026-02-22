from pydantic import BaseModel, EmailStr, Field, validator, AnyHttpUrl
from typing import Optional, List
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    # MED-6: must be a valid HTTPS URL, not an arbitrary string
    profile_pic: Optional[AnyHttpUrl] = None

class UserCreate(UserBase):
    # MED-1: minimum length + complexity enforced
    password: str = Field(..., min_length=8, max_length=128)

    @validator('password')
    def password_complexity(cls, v):
        if not any(c.isdigit() or not c.isalpha() for c in v):
            raise ValueError('Password must contain at least one number or special character')
        return v

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
    location_type: Optional[str] = None  # home, cafe, gym, office, outdoor

class NoteCreate(BaseModel):
    # MED-8: cap at 50k characters to prevent unbounded DB / memory usage
    content: str = Field(..., min_length=1, max_length=50000)
    location: Optional[LocationContext] = None

class NoteResponse(BaseModel):
    id: int
    content: str
    is_favorite: bool
    created_at: datetime

    class Config:
        from_attributes = True

class ChatRequest(BaseModel):
    # MED-8: cap at 2k characters — prevents token exhaustion in Gemini
    query: str = Field(..., min_length=1, max_length=2000)
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