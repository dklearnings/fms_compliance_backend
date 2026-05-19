SELECT
    COUNT(*) AS total_rows,
    MIN(started_at) AS earliest_record,
    MAX(ended_at) AS latest_record
FROM activity_records;


--Check No Overlaps

SELECT a1.driver_id
FROM activity_records a1
JOIN activity_records a2
ON a1.driver_id = a2.driver_id
AND a1.record_id <> a2.record_id
AND tstzrange(a1.started_at, a1.ended_at, '[)')
    &&
    tstzrange(a2.started_at, a2.ended_at, '[)')
LIMIT 1;


--Check Violations Exist
SELECT
    driver_id,
    DATE(started_at),
    SUM(duration_seconds)
FROM activity_records
WHERE activity_type = 'DRIVING'
GROUP BY 1,2
HAVING SUM(duration_seconds) > 32400;