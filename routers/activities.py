from fastapi import APIRouter
from fastapi import Request
from fastapi.responses import JSONResponse

from psycopg.errors import DatabaseError

from app.database import pool
from app.models.activity import (
    SubmitActivityRequest
)

router = APIRouter()

@router.post("/drivers/{driver_id}/activity")
async def submit_activity_record(
    driver_id: str,
    payload: SubmitActivityRequest,
    request: Request
):

    correlation_id = request.state.correlation_id

    idempotency_key = request.headers.get(
        "Idempotency-Key"
    )

    source_reference = (
        idempotency_key
        or payload.source_reference
    )

    try:

        with pool.connection() as conn:

            with conn.cursor() as cur:

                cur.execute(
                    """
                    SELECT *
                    FROM create_activity_record(
                        %s,
                        %s,
                        %s,
                        %s,
                        %s,
                        %s
                    )
                    """,
                    (
                        driver_id,
                        payload.vehicle_id,
                        payload.activity_type,
                        payload.started_at,
                        payload.ended_at,
                        source_reference
                    )
                )

                row = cur.fetchone()

                conn.commit()

        response_body = {
            "record_id": row[0],
            "duration_seconds": row[1],
            "was_duplicate": row[2]
        }

        if row[2]:
            return JSONResponse(
                status_code=200,
                content=response_body
            )

        return JSONResponse(
            status_code=201,
            content=response_body
        )

    except DatabaseError as ex:

        sqlstate = ex.sqlstate

        if sqlstate == "23P01":

            return JSONResponse(
                status_code=409,
                content={
                    "type": "https://example.com/errors/activity-overlap",
                    "title": "Activity overlap",
                    "status": 409,
                    "detail": str(ex),
                    "instance": str(request.url)
                }
            )

        if sqlstate == "22023":

            return JSONResponse(
                status_code=400,
                content={
                    "type": "https://example.com/errors/invalid-input",
                    "title": "Invalid activity",
                    "status": 400,
                    "detail": str(ex),
                    "instance": str(request.url)
                }
            )

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