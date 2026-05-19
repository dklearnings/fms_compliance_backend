from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class ComplianceCheckRequest(BaseModel):
    run_id: UUID
    period_start: datetime
    period_end: datetime