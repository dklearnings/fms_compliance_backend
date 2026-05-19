from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class SubmitActivityRequest(BaseModel):
    vehicle_id: UUID
    activity_type: str
    started_at: datetime
    ended_at: datetime
    source_reference: str | None = None


class SubmitActivityResponse(BaseModel):
    record_id: UUID
    duration_seconds: int
    was_duplicate: bool