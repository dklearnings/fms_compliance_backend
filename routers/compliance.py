from fastapi import APIRouter
from fastapi import BackgroundTasks
from fastapi import Request
from fastapi.responses import JSONResponse
from uuid import UUID
from psycopg.errors import DatabaseError
from typing import Optional
import base64

from database import pool
from models.compliance import (
    ComplianceCheckRequest,
    ComplianceRunResponse,
    ViolationSummary,
    ViolationDetail,
    ViolationsListResponse
)
from logger_config import get_logger

logger = get_logger(__name__)

router = APIRouter()

def execute_compliance(
    driver_id,
    payload
):

    with pool.connection() as conn:

        with conn.cursor() as cur:

            cur.execute(
                """
                CALL fms.sp_run_compliance_check(
                    %s,
                    %s,
                    %s,
                    %s
                )
                """,
                (
                    driver_id,
                    payload.period_start,
                    payload.period_end,
                    payload.run_id
                )
            )

            conn.commit()
            conn.close()


@router.post(
    "/drivers/{driver_id}/compliance-check",
    status_code=202
)
async def run_compliance_check_endpoint(
    driver_id: str,
    payload: ComplianceCheckRequest,
    background_tasks: BackgroundTasks
):
    

    background_tasks.add_task(
        execute_compliance,
        driver_id,
        payload
    )

    return {
        "run_id": str(payload.run_id),
        "status": "ACCEPTED"
    }


@router.get(
    "/drivers/{driver_id}/compliance-runs/{run_id}",
    status_code=200,
    response_model=ComplianceRunResponse
)
async def get_compliance_run(
    driver_id: str,
    run_id: str,
    request: Request
):
    """
    Get compliance run status and violation summary.
    Returns the status of a compliance run and breakdown of violations found.
    """
    
    correlation_id = request.state.correlation_id
    
    try:
        run_uuid = UUID(run_id)
        driver_uuid = UUID(driver_id)
    except ValueError:
        return JSONResponse(
            status_code=400,
            content={
                "type": "https://example.com/errors/invalid-input",
                "title": "Invalid UUID",
                "status": 400,
                "detail": "Invalid driver_id or run_id format",
                "instance": str(request.url)
            }
        )
    
    try:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                # Get compliance run details
                cur.execute(
                    """
                    SELECT
                        run_id,
                        driver_id,
                        status,
                        triggered_at,
                        completed_at,
                        period_start,
                        period_end,
                        violations_found
                    FROM fms.compliance_runs
                    WHERE run_id = %s
                      AND driver_id = %s
                    """,
                    (run_uuid, driver_uuid)
                )
                
                run_row = cur.fetchone()
                
                if not run_row:
                    return JSONResponse(
                        status_code=404,
                        content={
                            "type": "https://example.com/errors/not-found",
                            "title": "Compliance Run Not Found",
                            "status": 404,
                            "detail": f"No compliance run found for driver {driver_id} with run_id {run_id}",
                            "instance": str(request.url)
                        }
                    )
                
                # Get violation summary grouped by violation_type and severity
                cur.execute(
                    """
                    SELECT
                        violation_type,
                        severity,
                        COUNT(*) as count
                    FROM fms.compliance_violations
                    WHERE detection_run_id = %s
                    GROUP BY violation_type, severity
                    ORDER BY violation_type, severity
                    """,
                    (run_uuid,)
                )
                
                violation_rows = cur.fetchall()
                
                # Build violation summary
                violation_summary_dict = {}
                for vrow in violation_rows:
                    violation_type = vrow[0]
                    severity = vrow[1]
                    count = vrow[2]
                    
                    if violation_type not in violation_summary_dict:
                        violation_summary_dict[violation_type] = {
                            "count": 0,
                            "severity_breakdown": {}
                        }
                    
                    violation_summary_dict[violation_type]["count"] += count
                    violation_summary_dict[violation_type]["severity_breakdown"][severity] = count
                
                # Convert to list format
                violation_summary = [
                    ViolationSummary(
                        violation_type=vtype,
                        count=details["count"],
                        severity_breakdown=details["severity_breakdown"]
                    )
                    for vtype, details in violation_summary_dict.items()
                ]
                
                return ComplianceRunResponse(
                    run_id=run_row[0],
                    driver_id=run_row[1],
                    status=run_row[2],
                    triggered_at=run_row[3],
                    completed_at=run_row[4],
                    period_start=run_row[5],
                    period_end=run_row[6],
                    violations_found=run_row[7] or 0,
                    violation_summary=violation_summary
                )
    
    except DatabaseError as ex:
        logger.error(f"Database error in get_compliance_run. Correlation ID: {correlation_id}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "type": "https://example.com/errors/internal",
                "title": "Internal Server Error",
                "status": 500,
                "detail": f"Correlation ID: {correlation_id}",
                "instance": str(request.url)
            }
        )
    
    except Exception as ex:
        logger.error(f"Unexpected error in get_compliance_run. Correlation ID: {correlation_id}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "type": "https://example.com/errors/internal",
                "title": "Internal Server Error",
                "status": 500,
                "detail": f"Correlation ID: {correlation_id}",
                "instance": str(request.url)
            }
        )


@router.get(
    "/drivers/{driver_id}/violations",
    status_code=200,
    response_model=ViolationsListResponse
)
async def list_violations(
    driver_id: str,
    request: Request,
    cursor: Optional[str] = None,
    violation_type: Optional[str] = None,
    severity: Optional[str] = None,
    limit: int = 20
):
    """
    List violations for a driver with cursor-based pagination.
    Supports filtering by violation_type and severity.
    """
    
    correlation_id = request.state.correlation_id
    
    # Validate limit
    if limit < 1 or limit > 100:
        limit = 20
    
    try:
        driver_uuid = UUID(driver_id)
    except ValueError:
        return JSONResponse(
            status_code=400,
            content={
                "type": "https://example.com/errors/invalid-input",
                "title": "Invalid UUID",
                "status": 400,
                "detail": "Invalid driver_id format",
                "instance": str(request.url)
            }
        )
    
    # Decode cursor if provided
    cursor_violation_id = None
    if cursor:
        try:
            cursor_violation_id = UUID(base64.b64decode(cursor).decode('utf-8'))
        except Exception:
            return JSONResponse(
                status_code=400,
                content={
                    "type": "https://example.com/errors/invalid-input",
                    "title": "Invalid Cursor",
                    "status": 400,
                    "detail": "Invalid cursor format",
                    "instance": str(request.url)
                }
            )
    
    try:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                
                # Build dynamic WHERE clause for filters
                where_clauses = ["driver_id = %s"]
                params = [driver_uuid]
                
                if violation_type:
                    where_clauses.append("violation_type = %s")
                    params.append(violation_type)
                
                if severity:
                    where_clauses.append("severity = %s")
                    params.append(severity)
                
                # Add cursor condition (keyset pagination)
                if cursor_violation_id:
                    where_clauses.append("violation_id > %s")
                    params.append(cursor_violation_id)
                
                where_clause = " AND ".join(where_clauses)
                
                # Fetch limit + 1 to determine if there are more records
                cur.execute(
                    f"""
                    SELECT
                        violation_id,
                        driver_id,
                        violation_type,
                        severity,
                        period_start,
                        period_end,
                        measured_value_seconds,
                        threshold_seconds,
                        detection_run_id
                    FROM fms.compliance_violations
                    WHERE {where_clause}
                    ORDER BY violation_id ASC
                    LIMIT %s
                    """,
                    params + [limit + 1]
                )
                
                rows = cur.fetchall()
                
                # Determine if there are more records
                has_more = len(rows) > limit
                if has_more:
                    rows = rows[:limit]
                
                # Build violations list
                violations = [
                    ViolationDetail(
                        violation_id=row[0],
                        driver_id=row[1],
                        violation_type=row[2],
                        severity=row[3],
                        period_start=row[4],
                        period_end=row[5],
                        measured_value_seconds=row[6],
                        threshold_seconds=row[7],
                        detection_run_id=row[8]
                    )
                    for row in rows
                ]
                
                # Encode next cursor if there are more records
                next_cursor = None
                if has_more and violations:
                    last_violation_id = violations[-1].violation_id
                    next_cursor = base64.b64encode(
                        str(last_violation_id).encode('utf-8')
                    ).decode('utf-8')
                
                return ViolationsListResponse(
                    violations=violations,
                    cursor=next_cursor,
                    has_more=has_more
                )
    
    except DatabaseError as ex:
        logger.error(f"Database error in list_violations. Correlation ID: {correlation_id}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "type": "https://example.com/errors/internal",
                "title": "Internal Server Error",
                "status": 500,
                "detail": f"Correlation ID: {correlation_id}",
                "instance": str(request.url)
            }
        )
    
    except Exception as ex:
        logger.error(f"Unexpected error in list_violations. Correlation ID: {correlation_id}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "type": "https://example.com/errors/internal",
                "title": "Internal Server Error",
                "status": 500,
                "detail": f"Correlation ID: {correlation_id}",
                "instance": str(request.url)
            }
        )

