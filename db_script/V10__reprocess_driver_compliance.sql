-- =========================================================
-- V10__reprocess_driver_compliance.sql
-- =========================================================

CREATE OR REPLACE PROCEDURE sp_reprocess_driver_compliance
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

    v_existing_run UUID;

    v_violation_count INTEGER;

BEGIN

    -- =====================================================
    -- Idempotency Check
    -- =====================================================

    SELECT run_id
    INTO v_existing_run
    FROM fms.compliance_runs
    WHERE run_id = p_run_id;

    IF FOUND THEN

        RAISE NOTICE
            'Reprocess run already executed: %',
            p_run_id;

        RETURN;

    END IF;

    -- =====================================================
    -- Driver-level lock
    -- Prevent concurrent reprocessing
    -- =====================================================

    PERFORM pg_advisory_xact_lock
    (
        hashtext(p_driver_id::text)
    );

    -- =====================================================
    -- Create run record
    -- =====================================================

    INSERT INTO fms.compliance_runs
    (
        run_id,
        driver_id,
        triggered_at,
        period_start,
        period_end,
        status,
        run_type
    )
    VALUES
    (
        p_run_id,
        p_driver_id,
        CURRENT_TIMESTAMP,
        p_period_start,
        p_period_end,
        'RUNNING',
        'REPROCESS'
    );

    -- =====================================================
    -- Temporary staging table
    -- Transaction scoped
    -- =====================================================

    CREATE TEMP TABLE tmp_compliance_violations
    (
        violation_type violation_type_enum,
        severity violation_severity_enum,
        period_start TIMESTAMPTZ,
        period_end TIMESTAMPTZ,
        measured_value_seconds BIGINT,
        threshold_seconds BIGINT
    )
    ON COMMIT DROP;

    -- =====================================================
    -- DAILY DRIVING LIMIT
    -- =====================================================

    INSERT INTO tmp_compliance_violations
    (
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds
    )
    WITH daily_driving AS
    (
        SELECT
            date_trunc('day', started_at) AS driving_day,
            SUM(duration_seconds) AS total_seconds
        FROM fms.activity_records
        WHERE driver_id = p_driver_id
          AND activity_type = 'DRIVING'
          AND started_at >= p_period_start
          AND ended_at <= p_period_end
        GROUP BY 1
    )
    SELECT
        'DAILY_DRIVING_LIMIT',
        CASE
            WHEN total_seconds > 36000
                THEN 'CRITICAL'
            ELSE 'HIGH'
        END,
        driving_day,
        driving_day + interval '1 day',
        total_seconds,
        32400
    FROM daily_driving
    WHERE total_seconds > 32400;

    -- =====================================================
    -- WEEKLY DRIVING LIMIT
    -- =====================================================

    INSERT INTO tmp_compliance_violations
    (
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds
    )
    WITH weekly_driving AS
    (
        SELECT
            date_trunc('week', started_at) AS week_start,
            SUM(duration_seconds) AS total_seconds
        FROM activity_records
        WHERE driver_id = p_driver_id
          AND activity_type = 'DRIVING'
          AND started_at >= p_period_start
          AND ended_at <= p_period_end
        GROUP BY 1
    )
    SELECT
        'WEEKLY_DRIVING_LIMIT',
        'CRITICAL',
        week_start,
        week_start + interval '7 days',
        total_seconds,
        201600
    FROM weekly_driving
    WHERE total_seconds > 201600;

    -- =====================================================
    -- BIWEEKLY LIMIT
    -- =====================================================

    INSERT INTO tmp_compliance_violations
    (
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds
    )
    WITH weekly AS
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
    SELECT
        'WEEKLY_DRIVING_LIMIT',
        'CRITICAL',
        week_start,
        week_start + interval '14 days',
        combined_seconds,
        324000
    FROM biweekly
    WHERE combined_seconds > 324000;

    -- =====================================================
    -- Validate staging generated successfully
    -- =====================================================

    SELECT COUNT(*)
    INTO v_violation_count
    FROM tmp_compliance_violations;

    -- =====================================================
    -- Delete ONLY AFTER successful recomputation
    -- =====================================================

    DELETE FROM compliance_violations
    WHERE driver_id = p_driver_id
      AND period_start >= p_period_start
      AND period_end <= p_period_end;

    -- =====================================================
    -- Insert rebuilt violations
    -- =====================================================

    INSERT INTO fms.compliance_violations
    (
        violation_id,
        driver_id,
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds,
        detected_at,
        detection_run_id
    )
    SELECT
        gen_random_uuid(),
        p_driver_id,
        violation_type,
        severity,
        period_start,
        period_end,
        measured_value_seconds,
        threshold_seconds,
        CURRENT_TIMESTAMP,
        p_run_id
    FROM tmp_compliance_violations;

    -- =====================================================
    -- Complete run
    -- =====================================================

    UPDATE fms.compliance_runs
    SET
        status = 'COMPLETED',
        completed_at = CURRENT_TIMESTAMP,
        violations_found = v_violation_count
    WHERE run_id = p_run_id;

EXCEPTION

    WHEN OTHERS THEN

        -- ================================================
        -- Mark run failed
        -- ================================================

        UPDATE fms.compliance_runs
        SET
            status = 'FAILED',
            completed_at = CURRENT_TIMESTAMP,
            error_message = SQLERRM
        WHERE run_id = p_run_id;

        RAISE;

END;
$$;