from pydantic import BaseModel, EmailStr, Field, validator, AnyHttpUrl
from typing import Optional, List
from datetime import datetime


class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    # MED-6: must be a valid HTTPS URL, not an arbitrary string
    profile_pic: Optional[AnyHttpUrl] = None
    weight_kg: Optional[float] = None
    height_cm: Optional[float] = None


class UserCreate(UserBase):
    # MED-1: minimum length + complexity enforced
    password: str = Field(..., min_length=8, max_length=128)

    @validator("password")
    def password_complexity(cls, v):
        if not any(c.isdigit() or not c.isalpha() for c in v):
            raise ValueError(
                "Password must contain at least one number or special character"
            )
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(UserBase):
    id: int
    has_completed_life_path: bool
    macro_goal: Optional[str] = None
    last_lifepath_eval: Optional[datetime] = None
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


class MusicTrack(BaseModel):
    title: str
    artist: str


class MusicContextRequest(BaseModel):
    is_playing_now: bool
    current_song: Optional[MusicTrack] = None
    recent_songs: Optional[List[MusicTrack]] = None
    music_user_token: Optional[str] = None  # Needed to fetch from Apple Music API


class MusicContextResponse(BaseModel):
    primary_tone: str
    short_description: str
    valence: float = 0.0
    arousal: float = 0.0
    dominance: float = 0.0


class HealthSnapshotBase(BaseModel):
    readiness: Optional[str] = None
    heart_rate: Optional[dict] = None
    hrv: Optional[dict] = None
    sleep: Optional[dict] = None
    steps_today: Optional[int] = None
    active_energy_kcal: Optional[float] = None
    last_workout: Optional[dict] = None
    fetched_at: datetime


class HealthSnapshotCreate(HealthSnapshotBase):
    pass


class HealthSnapshotResponse(HealthSnapshotBase):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class NoteCreate(BaseModel):
    # MED-8: cap at 50k characters to prevent unbounded DB / memory usage
    content: str = Field(..., min_length=1, max_length=50000)
    location: Optional[LocationContext] = None


class NoteResponse(BaseModel):
    id: int
    content: str
    title: Optional[str] = None
    location_name: Optional[str] = None
    music_track: Optional[str] = None
    focus_mode: Optional[str] = None
    health_readiness: Optional[str] = None
    is_favorite: bool
    sentiment: Optional[str] = None
    categories: Optional[List[str]] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ChatRequest(BaseModel):
    # MED-8: cap at 2k characters — prevents token exhaustion in Gemini
    query: str = Field(..., min_length=1, max_length=2000)
    location: Optional[LocationContext] = None
    music_context: Optional[dict] = None
    health_context: Optional[dict] = None


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


class LifePathBaselineRequest(BaseModel):
    baseline_text: str
    macro_goal: str


class LifePathNodeResponse(BaseModel):
    id: int
    user_id: int
    computed_at: datetime
    trajectory: dict
    context_snapshot: dict
    embedding_id: Optional[str] = None

    class Config:
        from_attributes = True
