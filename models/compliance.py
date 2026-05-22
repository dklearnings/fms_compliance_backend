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


class ViolationDetail(BaseModel):
    violation_id: UUID
    driver_id: UUID
    violation_type: str
    severity: str
    period_start: datetime
    period_end: datetime
    measured_value_seconds: int
    threshold_seconds: int
    detection_run_id: UUID


class ViolationsListResponse(BaseModel):
    violations: List[ViolationDetail]
    cursor: Optional[str] = None
    has_more: bool