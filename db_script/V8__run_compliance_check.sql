-- =====================================================
-- V8__run_compliance_check.sql
-- =====================================================

CREATE OR REPLACE PROCEDURE sp_run_compliance_check
(
    p_driver_id UUID,
    p_period_start TIMESTAMPTZ,
    p_period_end TIMESTAMPTZ,
    p_run_id UUID
)
LANGUAGE plpgsql
AS
$$
DECLARE
    v_week_extension_days INTEGER;
BEGIN

    -- =====================================================
    -- Idempotency for compliance run
    -- =====================================================

    IF EXISTS
    (
        SELECT 1
        FROM fms.compliance_runs
        WHERE run_id = p_run_id
    )
    THEN
        RAISE NOTICE 'Compliance run already exists: %', p_run_id;
        RETURN;
    END IF;

    INSERT INTO fms.compliance_runs
    (
        run_id,
        driver_id,
        triggered_at,
        period_start,
        period_end,
        status
    )
    VALUES
    (
        p_run_id,
        p_driver_id,
        CURRENT_TIMESTAMP,
        p_period_start,
        p_period_end,
        'RUNNING'
    )
    ON CONFLICT (run_id) DO NOTHING;


    -- =====================================================
    -- RULE 1:
    -- DAILY_DRIVING_EXCEEDED
    -- =====================================================

    WITH daily_driving AS
    (
        SELECT
            DATE(started_at AT TIME ZONE 'UTC') AS driving_day,
            SUM(duration_seconds) AS total_seconds
        FROM fms.activity_records
        WHERE driver_id = p_driver_id
          AND activity_type = 'DRIVING'
          AND started_at >= p_period_start
          AND ended_at <= p_period_end
        GROUP BY 1
    )
    INSERT INTO fms.compliance_violations
    (
        driver_id,
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds,
        detection_run_id
    )
    SELECT
        p_driver_id,
        'DAILY_DRIVING_LIMIT',
        CASE
            WHEN total_seconds > 36000 THEN 'CRITICAL'
            ELSE 'HIGH'
        END,
        driving_day,
        driving_day + interval '1 day',
        total_seconds,
        32400,
        p_run_id
    FROM daily_driving
    WHERE total_seconds > 32400;

    -- =====================================================
    -- RULE 2:
    -- WEEKLY_DRIVING_EXCEEDED
    -- =====================================================

    WITH weekly_driving AS
    (
        SELECT
            date_trunc('week', started_at) AS week_start,
            SUM(duration_seconds) AS total_seconds
        FROM fms.activity_records
        WHERE driver_id = p_driver_id
          AND activity_type = 'DRIVING'
          AND started_at >= p_period_start
          AND ended_at <= p_period_end
        GROUP BY 1
    )
    INSERT INTO fms.compliance_violations
    (
        driver_id,
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds,
        detection_run_id
    )
    SELECT
        p_driver_id,
        'WEEKLY_DRIVING_LIMIT',
        'CRITICAL',
        week_start,
        week_start + interval '7 days',
        total_seconds,
        201600,
        p_run_id
    FROM weekly_driving
    WHERE total_seconds > 201600;

    -- =====================================================
    -- RULE 3:
    -- BIWEEKLY_DRIVING_EXCEEDED
    -- =====================================================

    WITH weekly AS
    (
        SELECT
            date_trunc('week', started_at) AS week_start,
            SUM(duration_seconds) AS total_seconds
        FROM fms.activity_records
        WHERE driver_id = p_driver_id
          AND activity_type = 'DRIVING'
        GROUP BY 1
    ),
    biweekly AS
    (
        SELECT
            w1.week_start,
            w1.total_seconds
            +
            COALESCE(w2.total_seconds, 0)
            AS combined_seconds
        FROM weekly w1
        LEFT JOIN weekly w2
            ON w2.week_start = w1.week_start + interval '7 days'
    )
    INSERT INTO fms.compliance_violations
    (
        driver_id,
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds,
        detection_run_id
    )
    SELECT
        p_driver_id,
        'WEEKLY_DRIVING_LIMIT',
        'CRITICAL',
        week_start,
        week_start + interval '14 days',
        combined_seconds,
        324000,
        p_run_id
    FROM biweekly
    WHERE combined_seconds > 324000;

    -- =====================================================
    -- RULE 4:
    -- Continuous driving without qualifying break (4.5 hours)
    -- Detects contiguous driving spans using gap detection
    -- =====================================================

    WITH ordered_driving AS
    (
        SELECT
            record_id,
            driver_id,
            started_at,
            ended_at,
            duration_seconds,
            activity_type,
            LAG(ended_at)
                OVER (ORDER BY started_at) AS prev_ended_at,
            CASE
                WHEN LAG(activity_type)
                    OVER (ORDER BY started_at) = 'DRIVING'
                    AND (EXTRACT(EPOCH FROM (started_at - LAG(ended_at)
                        OVER (ORDER BY started_at))) / 60) <= 15
                THEN 0
                ELSE 1
            END AS is_new_group
        FROM fms.activity_records
        WHERE driver_id = p_driver_id
          AND activity_type = 'DRIVING'
          AND started_at >= p_period_start
          AND ended_at <= p_period_end
    ),
    driving_groups AS
    (
        SELECT
            *,
            SUM(is_new_group)
                OVER (ORDER BY started_at) AS group_id
        FROM ordered_driving
    ),
    continuous_spans AS
    (
        SELECT
            group_id,
            MIN(started_at) AS span_start,
            MAX(ended_at) AS span_end,
            SUM(duration_seconds) AS total_driving_seconds
        FROM driving_groups
        GROUP BY group_id
        HAVING SUM(duration_seconds) > 16200
    )
    INSERT INTO fms.compliance_violations
    (
        driver_id,
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds,
        detection_run_id
    )
    SELECT
        p_driver_id,
        'EXCESS_CONTINUOUS_DRIVING',
        'HIGH',
        span_start,
        span_end,
        total_driving_seconds,
        16200,
        p_run_id
    FROM continuous_spans;

    -- =====================================================
    -- Mark completed
    -- =====================================================

    UPDATE fms.compliance_runs
    SET
        status = 'COMPLETED',
        completed_at = CURRENT_TIMESTAMP,
        violations_found =
        (
            SELECT COUNT(*)
            FROM compliance_violations
            WHERE detection_run_id = p_run_id
        )
    WHERE run_id = p_run_id;

EXCEPTION
    WHEN OTHERS THEN

        UPDATE fms.compliance_runs
        SET
            status = 'FAILED',
            completed_at = CURRENT_TIMESTAMP
        WHERE run_id = p_run_id;

        RAISE;
END;
$$;
