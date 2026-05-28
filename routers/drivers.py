from fastapi import APIRouter
from fastapi import Request
from fastapi import status

from models.driver import (
    CreateDriverRequest,
    CreateDriverResponse
)

from database import pool

router = APIRouter()

@router.post(
    "/drivers",
    response_model=CreateDriverResponse,
    status_code=status.HTTP_201_CREATED
)
async def create_driver(
    request: Request,
    payload: CreateDriverRequest
):

    correlation_id = request.state.correlation_id

    with pool.connection() as conn:

        with conn.cursor() as cur:

            cur.execute(
                """
                INSERT INTO fms.drivers
                (
                    full_name,
                    license_number,
                    card_number
                )
                VALUES
                (
                    %s,
                    %s,
                    %s
                )
                RETURNING driver_id
                """,
                (
                    payload.full_name,
                    payload.license_number,
                    payload.card_number
                )
            )

            row = cur.fetchone()

            conn.commit()

    return {
        "driver_id": row[0]
    }