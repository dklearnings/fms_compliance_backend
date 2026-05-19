import csv
import uuid
import random

from datetime import datetime
from datetime import timedelta
from faker import Faker

fake = Faker()

# ============================================================
# Deterministic seed
# ============================================================

random.seed(42)

# ============================================================
# Config
# ============================================================

NUM_DRIVERS = 50
NUM_WEEKS = 10
TARGET_ROWS = 150000

START_DATE = datetime(2026, 1, 1)

ACTIVITY_TYPES = [
    "DRIVING",
    "REST",
    "WORK",
    "AVAILABLE"
]

# ============================================================
# Driver IDs
# ============================================================

drivers = [uuid.uuid4() for _ in range(NUM_DRIVERS)]

vehicles = [uuid.uuid4() for _ in range(80)]

# ============================================================
# Output file
# ============================================================

output_file = "activity_records.csv"

# ============================================================
# Helper Functions
# ============================================================

def generate_driving_duration():

    # realistic driving segment:
    # 30m to 4.5h

    return random.randint(1800, 16200)


def generate_rest_duration():

    # 15m to overnight

    return random.choice([
        900,
        1800,
        2700,
        3600,
        39600
    ])


def generate_work_duration():

    return random.randint(900, 7200)


def should_generate_violation():

    return random.random() < 0.15


# ============================================================
# Generate Data
# ============================================================

rows_written = 0

with open(output_file, "w", newline="") as csvfile:

    writer = csv.writer(csvfile)

    writer.writerow([
        "record_id",
        "driver_id",
        "vehicle_id",
        "activity_type",
        "started_at",
        "ended_at",
        "source_reference",
        "created_at"
    ])

    for driver_id in drivers:

        current_time = START_DATE

        for week in range(NUM_WEEKS):

            for day in range(7):

                # ====================================================
                # Start around early morning
                # ====================================================

                current_time = current_time.replace(
                    hour=random.randint(5, 7),
                    minute=0,
                    second=0
                )

                total_daily_driving = 0

                violation_mode = should_generate_violation()

                segments = random.randint(8, 16)

                for segment in range(segments):

                    # ====================================================
                    # Choose next activity
                    # ====================================================

                    if segment % 2 == 0:
                        activity_type = "DRIVING"
                    else:
                        activity_type = random.choice([
                            "REST",
                            "WORK",
                            "AVAILABLE"
                        ])

                    # ====================================================
                    # Duration logic
                    # ====================================================

                    if activity_type == "DRIVING":

                        if violation_mode:

                            # intentional excessive driving

                            duration = random.randint(
                                12000,
                                22000
                            )

                        else:

                            duration = generate_driving_duration()

                        total_daily_driving += duration

                    elif activity_type == "REST":

                        if violation_mode:

                            # intentional invalid short break

                            duration = random.choice([
                                300,
                                600,
                                900
                            ])

                        else:

                            duration = generate_rest_duration()

                    else:

                        duration = generate_work_duration()

                    started_at = current_time
                    ended_at = started_at + timedelta(
                        seconds=duration
                    )

                    writer.writerow([
                        str(uuid.uuid4()),
                        str(driver_id),
                        str(random.choice(vehicles)),
                        activity_type,
                        started_at.isoformat() + "Z",
                        ended_at.isoformat() + "Z",
                        str(uuid.uuid4()),
                        datetime.utcnow().isoformat() + "Z"
                    ])

                    rows_written += 1

                    current_time = ended_at

                # ====================================================
                # Overnight rest
                # ====================================================

                overnight_rest = timedelta(hours=10)

                current_time += overnight_rest

print(f"Rows generated: {rows_written}")