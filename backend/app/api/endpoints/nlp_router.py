from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from app.services.llm_service import llm_service as gemini_service
from app.core.prompts import SMART_REMINDER_PARSER_PROMPT
from app.api.routers.auth import get_current_user
import json
import logging
#test
router = APIRouter(prefix="/api/nlp", tags=["nlp"])
logger = logging.getLogger(__name__)

class ReminderParseRequest(BaseModel):
    text: str
    timezone: str
    current_time: str

class RecurrenceSchema(BaseModel):
    frequency: Optional[str] = None
    interval: int = 1
    days_of_week: Optional[List[int]] = None
    end_date: Optional[str] = None

class ReminderParseResponse(BaseModel):
    action: str
    trigger_time: str
    recurrence: RecurrenceSchema

@router.post("/parse-reminder", response_model=ReminderParseResponse)
async def parse_reminder(
    request: ReminderParseRequest,
    current_user=Depends(get_current_user)
):
    """
    Parses a natural language reminder request into a structured format.
    """
    # Validation: Prevent oversized payloads
    if len(request.text) > 500:
        raise HTTPException(status_code=400, detail="Input text too long (max 500 chars)")

    prompt = SMART_REMINDER_PARSER_PROMPT.format(
        input_text=request.text,
        timezone=request.timezone,
        current_time=request.current_time
    )

    try:
        response_text = await gemini_service.generate_content(
            prompt=prompt,
            response_mime_type="application/json"
        )
        data = json.loads(response_text)
        
        # Handle 'INVALID' case explicitly
        if data.get("action") == "INVALID":
            raise HTTPException(status_code=400, detail="Could not understand the reminder request.")

        # Validate required fields or provide defaults
        return ReminderParseResponse(
            action=data.get("action", "Reminder"),
            trigger_time=data.get("trigger_time", request.current_time),
            recurrence=RecurrenceSchema(
                frequency=data.get("recurrence", {}).get("frequency"),
                interval=data.get("recurrence", {}).get("interval", 1),
                days_of_week=data.get("recurrence", {}).get("days_of_week"),
                end_date=data.get("recurrence", {}).get("end_date")
            )
        )
    except Exception as e:
        logger.error(f"Error parsing reminder: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to parse reminder: {str(e)}")
