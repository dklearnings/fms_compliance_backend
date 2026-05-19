-- =========================================================
-- V011__generate_activity_seed_data.sql
-- FINAL FLYWAY SAFE VERSION
-- =========================================================

DO
$$
DECLARE

    v_driver_id UUID;
    v_vehicle_id UUID;

    v_current_time TIMESTAMPTZ;

    v_started_at TIMESTAMPTZ;
    v_ended_at TIMESTAMPTZ;

    v_activity_type fms.activity_type_enum;

    v_duration_seconds INTEGER;

    v_violation_mode BOOLEAN;

    v_week_counter INTEGER;
    v_day_counter INTEGER;

    v_total_rows BIGINT := 0;

    v_day_start TIMESTAMPTZ;
    v_day_end TIMESTAMPTZ;

BEGIN

    -- =====================================================
    -- IMPORTANT:
    -- Clear old generated rows first
    -- =====================================================

    TRUNCATE TABLE fms.activity_records;

    -- =====================================================
    -- Process drivers
    -- =====================================================

    FOR v_driver_id IN
    (
        SELECT driver_id
        FROM fms.drivers
        ORDER BY driver_id
        LIMIT 50
    )
    LOOP

        -- =================================================
        -- Proper TIMESTAMPTZ assignment
        -- =================================================

        v_current_time :=
            TIMESTAMPTZ '2026-01-01 05:00:00+00'
            +
            make_interval(
                mins => floor(random() * 180)::INT
            );

        -- =================================================
        -- Generate 10 weeks
        -- =================================================

        FOR v_week_counter IN 1..10 LOOP

            FOR v_day_counter IN 1..7 LOOP

                -- =========================================
                -- Daily operational window
                -- =========================================

                v_day_start := v_current_time;

                v_day_end :=
                    v_day_start
                    + INTERVAL '14 hours';

                -- =========================================
                -- Some days intentionally violate rules
                -- =========================================

                v_violation_mode :=
                    random() < 0.15;

                -- =========================================
                -- Generate sequential activities
                -- =========================================

                WHILE v_current_time < v_day_end LOOP

                    -- =====================================
                    -- DRIVING segment
                    -- =====================================

                    v_activity_type := 'DRIVING';

                    IF v_violation_mode THEN

                        -- intentional long driving

                        v_duration_seconds :=
                            12000
                            +
                            floor(random() * 6000)::INT;

                    ELSE

                        -- realistic driving

                        v_duration_seconds :=
                            1800
                            +
                            floor(random() * 12600)::INT;

                    END IF;

                    -- =====================================
                    -- Prevent day overflow
                    -- =====================================

                    IF (
                        v_current_time
                        +
                        make_interval(
                            secs => v_duration_seconds
                        )
                    ) > v_day_end
                    THEN
                        EXIT;
                    END IF;

                    v_started_at := v_current_time;

                    v_ended_at :=
                        v_started_at
                        +
                        make_interval(
                            secs => v_duration_seconds
                        );

                    -- =====================================
                    -- Select vehicle
                    -- =====================================

                    SELECT vehicle_id
                    INTO v_vehicle_id
                    FROM fms.vehicles
                    ORDER BY random()
                    LIMIT 1;

                    -- =====================================
                    -- Insert DRIVING
                    -- =====================================

                    INSERT INTO fms.activity_records
                    (
                        record_id,
                        driver_id,
                        vehicle_id,
                        activity_type,
                        started_at,
                        ended_at,
                        source_reference,
                        created_at
                    )
                    VALUES
                    (
                        gen_random_uuid(),
                        v_driver_id,
                        v_vehicle_id,
                        v_activity_type,
                        v_started_at,
                        v_ended_at,
                        gen_random_uuid()::TEXT,
                        CURRENT_TIMESTAMP
                    );

                    v_total_rows :=
                        v_total_rows + 1;

                    v_current_time := v_ended_at;

                    -- =====================================
                    -- REST segment
                    -- =====================================

                    v_activity_type := 'REST';

                    IF v_violation_mode THEN

                        -- intentionally invalid short breaks

                        v_duration_seconds :=
                        (
                            ARRAY[
                                300,
                                600,
                                900
                            ]
                        )
                        [
                            1 + floor(random() * 3)::INT
                        ];

                    ELSE

                        -- realistic breaks

                        v_duration_seconds :=
                        (
                            ARRAY[
                                900,
                                1800,
                                2700,
                                3600
                            ]
                        )
                        [
                            1 + floor(random() * 4)::INT
                        ];

                    END IF;

                    -- =====================================
                    -- Prevent overflow
                    -- =====================================

                    IF (
                        v_current_time
                        +
                        make_interval(
                            secs => v_duration_seconds
                        )
                    ) > v_day_end
                    THEN
                        EXIT;
                    END IF;

                    v_started_at := v_current_time;

                    v_ended_at :=
                        v_started_at
                        +
                        make_interval(
                            secs => v_duration_seconds
                        );

                    -- =====================================
                    -- Insert REST
                    -- =====================================

                    INSERT INTO fms.activity_records
                    (
                        record_id,
                        driver_id,
                        vehicle_id,
                        activity_type,
                        started_at,
                        ended_at,
                        source_reference,
                        created_at
                    )
                    VALUES
                    (
                        gen_random_uuid(),
                        v_driver_id,
                        v_vehicle_id,
                        v_activity_type,
                        v_started_at,
                        v_ended_at,
                        gen_random_uuid()::TEXT,
                        CURRENT_TIMESTAMP
                    );

                    v_total_rows :=
                        v_total_rows + 1;

                    -- =====================================
                    -- Advance clock
                    -- =====================================

                    v_current_time := v_ended_at;

                END LOOP;

                -- =========================================
                -- Overnight mandatory rest
                -- =========================================

                v_current_time :=
                    v_day_end
                    + INTERVAL '10 hours';

            END LOOP;

        END LOOP;

    END LOOP;

    RAISE NOTICE
        'Seed generation completed. Rows inserted: %',
        v_total_rows;

END
$$;