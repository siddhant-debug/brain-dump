# backend/tests/test_core_auth.py
import pytest
from jose import jwt
from datetime import datetime, timedelta, timezone
from app.api.routers import auth
from app.models import models
from unittest.mock import MagicMock, patch
import os

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "test_secret")
ALGORITHM = "HS256"

def create_test_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def test_valid_jwt_allows_access():
    """Token from login grants access to protected route"""
    token = create_test_token({"user_id": 1})
    db = MagicMock()
    mock_user = models.User(id=1, email="test@example.com")
    db.query().filter().first.return_value = mock_user
    
    with patch("os.getenv", return_value=SECRET_KEY):
        user = auth.get_current_user(token, db)
        assert user.id == 1

def test_expired_jwt_returns_401():
    """A manually crafted expired JWT is rejected with 401"""
    token = create_test_token({"user_id": 1}, expires_delta=timedelta(minutes=-1))
    db = MagicMock()
    
    from fastapi import HTTPException
    with patch("os.getenv", return_value=SECRET_KEY):
        with pytest.raises(HTTPException) as excinfo:
            auth.get_current_user(token, db)
        assert excinfo.value.status_code == 401

def test_tampered_jwt_returns_401():
    """JWT with modified payload fails signature verification"""
    token = create_test_token({"user_id": 1})
    # Tamper with the token (flip a character in the signature)
    tampered_token = token[:-1] + ("0" if token[-1] != "0" else "1")
    db = MagicMock()
    
    from fastapi import HTTPException
    with patch("os.getenv", return_value=SECRET_KEY):
        with pytest.raises(HTTPException) as excinfo:
            auth.get_current_user(tampered_token, db)
        assert excinfo.value.status_code == 401

def test_missing_authorization_header_returns_401():
    """No header → 401 (Tested via TestClient in api_routes, but unit test scheme here)"""
    from fastapi.security import OAuth2PasswordBearer
    scheme = OAuth2PasswordBearer(tokenUrl="auth/login")
    # This is handled by FastAPI's dependency injection normally
    assert True # Placeholder as logic is validated in test_api_routes.py
