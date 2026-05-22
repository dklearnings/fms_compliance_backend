from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import List, Optional

class ComplianceCheckRequest(BaseModel):
    run_id: UUID
    period_start: datetime
    period_end: datetime


class ViolationSummary(BaseModel):
    violation_type: str
    count: int
    severity_breakdown: dict


class ComplianceRunResponse(BaseModel):
    run_id: UUID
    driver_id: UUID
    status: str
    triggered_at: datetime
    completed_at: Optional[datetime]
    period_start: datetime
    period_end: datetime
    violations_found: int
    violation_summary: List[ViolationSummary]