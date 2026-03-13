from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from app.core import database
from app.api.routers import auth
from app.models import models
from app.schemas import schemas

router = APIRouter()


@router.post("/context", response_model=schemas.HealthSnapshotResponse)
def sync_health_context(
    payload: schemas.HealthSnapshotCreate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """
    Receives HealthKit snapshot from the mobile app and stores it.
    Also updates static biometrics on the User model if provided.
    """
    # 1. Update User biometrics if they changed (weight/height)
    # Note: These might come in the metadata or we might expect them in a separate profile update.
    # For now, if the payload has them (if we were to add them to HealthSnapshotCreate), we'd update here.
    # However, per plan, they are on User model. The current HealthSnapshotBase doesn't have them.
    
    # 2. Create the snapshot
    db_snapshot = models.HealthSnapshot(
        user_id=current_user.id,
        readiness=payload.readiness,
        heart_rate=payload.heart_rate,
        hrv=payload.hrv,
        sleep=payload.sleep,
        steps_today=payload.steps_today,
        active_energy_kcal=payload.active_energy_kcal,
        last_workout=payload.last_workout,
        fetched_at=payload.fetched_at
    )
    
    db.add(db_snapshot)
    db.commit()
    db.refresh(db_snapshot)
    return db_snapshot


@router.get("/latest", response_model=schemas.HealthSnapshotResponse)
def get_latest_health(
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    """
    Returns the most recent health snapshot for the current user.
    """
    latest = (
        db.query(models.HealthSnapshot)
        .filter(models.HealthSnapshot.user_id == current_user.id)
        .order_by(models.HealthSnapshot.fetched_at.desc())
        .first()
    )
    
    if not latest:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No health data found for this user."
        )
    
    return latest
