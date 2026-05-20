-- =============================================
-- V2__core_tables.sql
-- =============================================

-- =============================================
-- Fleet Operators
-- =============================================

CREATE TABLE IF NOT EXISTS fms.fleet_operators
(
    fleet_operator_id UUID NOT NULL DEFAULT gen_random_uuid(),
    operator_name VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	constraint pk_fleet_operators_operator_id primary key (fleet_operator_id)
);

-- =============================================
-- Drivers
-- =============================================

CREATE TABLE IF NOT EXISTS fms.drivers
(
    driver_id UUID not null DEFAULT gen_random_uuid(),
    full_name VARCHAR(200) NOT NULL,
    license_number VARCHAR(100) NOT NULL,
    card_number VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT null DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    constraint pk_drivers_driver_id primary key (driver_id),
    constraint uk_drivers_license_number unique (license_number),
    constraint uk_drivers_card_number unique (card_number)    
);

-- =============================================
-- Vehicles
-- =============================================

CREATE TABLE IF NOT EXISTS fms.vehicles
(
    vehicle_id UUID NOT NULL DEFAULT gen_random_uuid(),
    vin VARCHAR(100) NOT NULL,
    registration_plate VARCHAR(50) NOT NULL,
    make VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
	fleet_operator_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,    
    CONSTRAINT pk_vehicles_vehicle_id PRIMARY KEY (vehicle_id),
	CONSTRAINT uk_vehicles_vin UNIQUE (vin),
    CONSTRAINT uk_vehicles_reg_plate UNIQUE (registration_plate),
	CONSTRAINT fk_vehicles_fleet_operator_id FOREIGN KEY (fleet_operator_id) 
	REFERENCES fms.fleet_operators(fleet_operator_id)
);

-- =============================================
-- Activity Records
-- =============================================

CREATE TABLE IF NOT EXISTS  fms.activity_records
(
    record_id UUID NOT NULL DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL,
    vehicle_id UUID NOT NULL,
    activity_type activity_type_enum NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    duration_seconds BIGINT GENERATED ALWAYS AS
    (
        EXTRACT(EPOCH FROM (ended_at - started_at))
    ) STORED,
    source_reference VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_activity_records_record_id PRIMARY KEY (record_id),
    CONSTRAINT fk_activity_records_driver_id FOREIGN KEY (driver_id) REFERENCES fms.drivers(driver_id),
    CONSTRAINT fk_activity_records_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES fms.vehicles(vehicle_id)
);


-- =============================================
-- Compliance Runs
-- =============================================

CREATE TABLE IF NOT EXISTS fms.compliance_runs
(
    run_id UUID NOT NULL DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES drivers(driver_id),
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    status compliance_run_status_enum NOT NULL,
    violations_found INT NOT NULL DEFAULT 0,
    completed_at TIMESTAMPTZ,
    CONSTRAINT pk_compliance_runs_run_id PRIMARY KEY (run_id),
    CONSTRAINT fk_compliance_runs_driver_id FOREIGN KEY (driver_id) REFERENCES fms.drivers(driver_id)
);



-- =============================================
-- Compliance Violations
-- =============================================

CREATE TABLE IF NOT EXISTS fms.compliance_violations
(
    violation_id UUID NOT NULL DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL,
    violation_type violation_type_enum NOT NULL,
    severity violation_severity_enum NOT NULL,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    measured_value_seconds BIGINT NOT NULL,
    threshold_seconds BIGINT NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    detection_run_id UUID NOT NULL,
    CONSTRAINT pk_compliance_violations_violation_id PRIMARY KEY (violation_id),
    CONSTRAINT fk_compliance_violations_driver_id FOREIGN KEY (driver_id) REFERENCES fms.drivers(driver_id),
    CONSTRAINT fk_compliance_violations_detection_run_id FOREIGN KEY (detection_run_id) REFERENCES fms.compliance_runs(run_id)

);
