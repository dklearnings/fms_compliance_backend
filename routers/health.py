import time

@router.get("/health")
async def health():

    started = time.time()

    with pool.connection() as conn:

        with conn.cursor() as cur:

            cur.execute("SELECT 1")

            cur.fetchone()

    latency_ms = round(
        (time.time() - started) * 1000,
        2
    )

    return {
        "status": "OK",
        "database": "CONNECTED",
        "latency_ms": latency_ms
    }