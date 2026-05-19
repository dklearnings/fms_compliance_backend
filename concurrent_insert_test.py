import uuid
import asyncio
import aiohttp
from datetime import datetime, timedelta, timezone

API_BASE = "http://localhost:8000"

DRIVER_ID = "11111111-1111-1111-1111-111111111111"
VEHICLE_ID = "22222222-2222-2222-2222-222222222222"

SUCCESS = 0
CONFLICT = 0
OTHER = 0

results = []


async def submit_activity(
    session,
    started_at,
    ended_at,
    request_no,
    overlap=False
):

    global SUCCESS, CONFLICT, OTHER

    payload = {
        "vehicle_id": VEHICLE_ID,
        "activity_type": "DRIVING",
        "started_at": started_at.isoformat(),
        "ended_at": ended_at.isoformat(),
        "source_reference": str(uuid.uuid4())
    }

    headers = {
        "Content-Type": "application/json",
        "Idempotency-Key": str(uuid.uuid4())
    }

    url = (
        f"{API_BASE}/drivers/"
        f"{DRIVER_ID}/activity"
    )

    try:

        async with session.post(
            url,
            json=payload,
            headers=headers
        ) as response:

            body = await response.text()

            result = {
                "request_no": request_no,
                "status": response.status,
                "overlap_test": overlap,
                "response": body
            }

            results.append(result)

            if response.status in (200, 201):
                SUCCESS += 1

            elif response.status == 409:
                CONFLICT += 1

            else:
                OTHER += 1

    except Exception as ex:

        results.append({
            "request_no": request_no,
            "status": "EXCEPTION",
            "error": str(ex)
        })

        OTHER += 1


async def main():

    tasks = []

    async with aiohttp.ClientSession() as session:

        base_time = datetime.now(
            timezone.utc
        ).replace(
            minute=0,
            second=0,
            microsecond=0
        )

        # =================================================
        # 15 NON-OVERLAPPING REQUESTS
        # =================================================

        for i in range(15):

            start = (
                base_time
                + timedelta(hours=i * 2)
            )

            end = start + timedelta(hours=1)

            tasks.append(
                submit_activity(
                    session,
                    start,
                    end,
                    request_no=i + 1,
                    overlap=False
                )
            )

        # =================================================
        # 5 OVERLAPPING REQUESTS
        # =================================================

        overlap_start = base_time + timedelta(hours=4)

        for i in range(5):

            start = overlap_start
            end = overlap_start + timedelta(hours=2)

            tasks.append(
                submit_activity(
                    session,
                    start,
                    end,
                    request_no=16 + i,
                    overlap=True
                )
            )

        await asyncio.gather(*tasks)

    # =====================================================
    # OUTPUT SUMMARY
    # =====================================================

    print("\n==============================")
    print("CONCURRENCY TEST SUMMARY")
    print("==============================")

    print(f"Successful Inserts : {SUCCESS}")
    print(f"409 Conflicts      : {CONFLICT}")
    print(f"Other Responses    : {OTHER}")

    print("\n==============================")
    print("DETAILED RESULTS")
    print("==============================")

    for r in sorted(
        results,
        key=lambda x: x["request_no"]
    ):
        print(r)


if __name__ == "__main__":
    asyncio.run(main())