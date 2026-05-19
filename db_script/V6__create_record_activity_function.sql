-- =========================================================
-- V6__create_record_activity_function.sql
-- =========================================================

CREATE OR REPLACE FUNCTION fn_create_activity_record
(
    p_driver_id          UUID,
    p_vehicle_id         UUID,
    p_activity_type      TEXT,
    p_started_at         TIMESTAMPTZ,
    p_ended_at           TIMESTAMPTZ,
    p_source_reference   TEXT
)
RETURNS TABLE
(
    record_id UUID,
    duration_seconds BIGINT,
    was_duplicate BOOLEAN
)
LANGUAGE plpgsql
AS
$$
DECLARE
    v_existing_record_id UUID;
    v_existing_duration  BIGINT;

    v_conflict_record_id UUID;
    v_conflict_start     TIMESTAMPTZ;
    v_conflict_end       TIMESTAMPTZ;

    v_inserted_record_id UUID;
    v_inserted_duration  BIGINT;
BEGIN

    -- =====================================================
    -- Validate activity type
    -- =====================================================

    IF p_activity_type NOT IN
    (
        'DRIVING',
        'REST',
        'WORK',
        'AVAILABLE'
    )
    THEN
        RAISE EXCEPTION
        USING
            ERRCODE = '22023',
            MESSAGE = format(
                'Invalid activity_type: %s',
                p_activity_type
            ),
            DETAIL = 'Allowed values: DRIVING, REST, WORK, AVAILABLE';
    END IF;

    -- =====================================================
    -- Validate timestamps
    -- =====================================================

    IF p_ended_at <= p_started_at THEN
        RAISE EXCEPTION
        USING
            ERRCODE = '22023',
            MESSAGE = 'ended_at must be greater than started_at',
            DETAIL = format(
                'started_at=%s ended_at=%s',
                p_started_at,
                p_ended_at
            );
    END IF;

    -- =====================================================
    -- Idempotency check
    -- =====================================================

    SELECT
        ar.record_id,
        ar.duration_seconds
    INTO
        v_existing_record_id,
        v_existing_duration
    FROM fms.activity_records ar
    WHERE ar.driver_id = p_driver_id
      AND ar.source_reference = p_source_reference;

    IF FOUND THEN

        record_id := v_existing_record_id;
        duration_seconds := v_existing_duration;
        was_duplicate := TRUE;

        RETURN NEXT;
        RETURN;

    END IF;

    -- =====================================================
    -- Manual overlap detection for custom error
    -- (before insert)
    -- =====================================================

    SELECT
        ar.record_id,
        ar.started_at,
        ar.ended_at
    INTO
        v_conflict_record_id,
        v_conflict_start,
        v_conflict_end
    FROM fms.activity_records ar
    WHERE ar.driver_id = p_driver_id
      AND tstzrange(ar.started_at, ar.ended_at, '[)')
          &&
          tstzrange(p_started_at, p_ended_at, '[)')
    LIMIT 1;

    IF FOUND THEN

        RAISE EXCEPTION
        USING
            ERRCODE = '23P01',
            MESSAGE = format(
                'Activity overlap detected with record_id=%s',
                v_conflict_record_id
            ),
            DETAIL = format(
                'Conflicting range: [%s - %s]',
                v_conflict_start,
                v_conflict_end
            ),
            HINT = 'Driver activity periods may not overlap';

    END IF;

    -- =====================================================
    -- Insert new record
    -- =====================================================

    INSERT INTO fms.activity_records
    (
        driver_id,
        vehicle_id,
        activity_type,
        started_at,
        ended_at,
        source_reference
    )
    VALUES
    (
        p_driver_id,
        p_vehicle_id,
        p_activity_type::activity_type_enum,
        p_started_at,
        p_ended_at,
        p_source_reference
    )
    RETURNING
        activity_records.record_id,
        activity_records.duration_seconds
    INTO
        v_inserted_record_id,
        v_inserted_duration;

    record_id := v_inserted_record_id;
    duration_seconds := v_inserted_duration;
    was_duplicate := FALSE;

    RETURN NEXT;

EXCEPTION

    -- =====================================================
    -- Defensive handling:
    -- race-condition overlap
    -- =====================================================

    WHEN exclusion_violation THEN

        RAISE EXCEPTION
        USING
            ERRCODE = '23P01',
            MESSAGE = 'Temporal overlap detected by exclusion constraint',
            DETAIL = SQLERRM;

END;
$$;