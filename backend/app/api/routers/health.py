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
    Deduplicates based on time (30m floor) and significant value changes.
    """
    # 1. Fetch the latest snapshot to compare
    latest = (
        db.query(models.HealthSnapshot)
        .filter(models.HealthSnapshot.user_id == current_user.id)
        .order_by(models.HealthSnapshot.fetched_at.desc())
        .first()
    )

    should_write = True
    if latest:
        # A. Time Floor (30 minutes)
        # SQLAlchemy dates are usually UTC but might be naive. Convert to UTC comparison.
        latest_fetched = latest.fetched_at.replace(tzinfo=None)
        time_diff = datetime.utcnow() - latest_fetched
        if time_diff.total_seconds() < 1800:  # 30 minutes
            should_write = False

            # B. Readiness Change (Categorical state overrides time floor)
            if payload.readiness != latest.readiness:
                should_write = True

            # C. Significant Delta Thresholds
            if not should_write:
                # Steps (Δ > 500)
                steps_diff = abs((payload.steps_today or 0) - (latest.steps_today or 0))
                if steps_diff >= 500:
                    should_write = True

                # Active Energy (Δ > 50)
                kcal_diff = abs((payload.active_energy_kcal or 0) - (latest.active_energy_kcal or 0))
                if kcal_diff >= 50:
                    should_write = True

                # HRV (Δ > 5ms)
                hrv_curr = payload.hrv.get("current") if payload.hrv else None
                latest_hrv_curr = latest.hrv.get("current") if latest.hrv else None
                if hrv_curr is not None and latest_hrv_curr is not None:
                    if abs(hrv_curr - latest_hrv_curr) >= 5:
                        should_write = True

                # Heart Rate (Δ > 5bpm resting)
                hr_resting = payload.heart_rate.get("resting") if payload.heart_rate else None
                latest_hr_resting = latest.heart_rate.get("resting") if latest.heart_rate else None
                if hr_resting is not None and latest_hr_resting is not None:
                    if abs(hr_resting - latest_hr_resting) >= 5:
                        should_write = True

    if not should_write:
        return latest

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
    try:
        db.commit()
    except Exception:
        db.rollback()
        # Fallback to latest to avoid 500 if the unique index triggers
        return latest 
        
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
