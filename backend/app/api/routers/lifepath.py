import logging
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.routers.auth import get_current_user
from app.schemas.schemas import LifePathBaselineRequest, LifePathNodeResponse, UserResponse, LifePathStatusResponse
from app.services.lifepath_service import lifepath_service
from app.models import models

router = APIRouter(prefix="/api/lifepath", tags=["lifepath"])
logger = logging.getLogger(__name__)

@router.post("/baseline")
async def set_baseline(
    request: LifePathBaselineRequest,
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Initializes user's life path baseline and goal."""
    try:
        user = await lifepath_service.initialize_baseline(
            user_id=current_user.id,
            baseline_text=request.baseline_text,
            macro_goal=request.macro_goal,
            db=db
        )
        return {"status": "success", "message": "Life path baseline initialized."}
    except Exception as e:
        logger.error(f"[LifePathRouter] Failed to set baseline: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to initialize life path."
        )

@router.post("/evaluate", response_model=LifePathNodeResponse)
async def trigger_evaluation(
    force: bool = False,
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Manual trigger for life path evaluation."""
    try:
        node = await lifepath_service.evaluate_daily_node(
            user_id=current_user.id,
            db=db,
            force=force
        )
        if not node:
            # Check if it was a deduplication skip
            user = db.query(models.User).filter(models.User.id == current_user.id).first()
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Wait for 24h between evaluations. Last eval: {user.last_lifepath_eval}"
            )
        return node
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[LifePathRouter] Evaluation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to run life path evaluation."
        )

@router.get("/history", response_model=List[LifePathNodeResponse])
def get_history(
    limit: int = 10,
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retrieve the recent evaluation nodes."""
    nodes = (
        db.query(models.LifePathNode)
        .filter(models.LifePathNode.user_id == current_user.id)
        .order_by(models.LifePathNode.computed_at.desc())
        .limit(limit)
        .all()
    )
    return nodes
@router.get("/status", response_model=LifePathStatusResponse)
def get_status(
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Returns the current high-level status of the user's Life Path."""
    user = db.query(models.User).filter(models.User.id == current_user.id).first()
    
    # If no macro goal, they don't have an active path
    if not user.macro_goal:
        return LifePathStatusResponse(
            has_active_path=False,
            alignment_score=None,
            macro_goal=None,
            last_eval_at=user.last_lifepath_eval
        )

    # Fetch most recent node for alignment calculation
    latest_node = (
        db.query(models.LifePathNode)
        .filter(models.LifePathNode.user_id == current_user.id)
        .order_by(models.LifePathNode.computed_at.desc())
        .first()
    )

    alignment_score = None
    if latest_node:
        # Simple heuristic: count positive/negative items in trajectory
        traj = latest_node.trajectory or {}
        progress = traj.get("progress", [])
        blockers = traj.get("blockers", [])
        total = len(progress) + len(blockers)
        if total > 0:
            alignment_score = int((len(progress) / total) * 100)

    return LifePathStatusResponse(
        has_active_path=True,
        alignment_score=alignment_score,
        macro_goal=user.macro_goal,
        last_eval_at=user.last_lifepath_eval
    )
