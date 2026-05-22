import time
from fastapi import APIRouter
from fastapi import Request
from fastapi.responses import JSONResponse
from psycopg.errors import DatabaseError
from pydantic import BaseModel
from typing import Optional

from app.database import pool
from app.logger_config import get_logger

logger = get_logger(__name__)

router = APIRouter()


class HealthResponse(BaseModel):
    status: str
    database: str
    latency_ms: float


@router.get("/health", status_code=200, response_model=HealthResponse)
async def health(request: Request):
    """
    Health check endpoint.
    Returns 200 OK with database connectivity status and response latency in ms.
    """
    
    correlation_id = getattr(request.state, 'correlation_id', 'N/A')
    started = time.time()
    db_status = "DISCONNECTED"
    
    try:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        
        db_status = "CONNECTED"
    
    except DatabaseError as ex:
        logger.error(f"Database connectivity check failed. Correlation ID: {correlation_id}", exc_info=True)
        db_status = "DISCONNECTED"
    
    except Exception as ex:
        logger.error(f"Unexpected error in health check. Correlation ID: {correlation_id}", exc_info=True)
        db_status = "DISCONNECTED"
    
    finally:
        latency_ms = round(
            (time.time() - started) * 1000,
            2
        )
    
    # Return 503 Service Unavailable if database is disconnected
    if db_status == "DISCONNECTED":
        return JSONResponse(
            status_code=503,
            content={
                "status": "DEGRADED",
                "database": "DISCONNECTED",
                "latency_ms": latency_ms
            }
        )
    
    return HealthResponse(
        status="OK",
        database=db_status,
        latency_ms=latency_ms
    )