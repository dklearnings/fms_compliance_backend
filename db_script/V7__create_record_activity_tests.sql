-- =========================================================
-- V7__create_record_activity_tests.sql
-- =========================================================

BEGIN;

TRUNCATE fms.activity_records CASCADE;
TRUNCATE fms.drivers CASCADE;
TRUNCATE fms.vehicles CASCADE;
TRUNCATE fms.fleet_operators CASCADE;

-- =========================================================
-- Seed data
-- =========================================================

INSERT INTO fms.fleet_operators
(
    fleet_operator_id,
    operator_name
)
VALUES
(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Fleet Operator'
);

INSERT INTO fms.drivers
(
    driver_id,
    full_name,
    license_number,
    card_number
)
VALUES
(
    '11111111-1111-1111-1111-111111111111',
    'John Driver',
    'LIC-001',
    'CARD-001'
);

INSERT INTO fms.vehicles
(
    vehicle_id,
    vin,
    registration_plate,
    make,
    model,
    fleet_operator_id
)
VALUES
(
    '22222222-2222-2222-2222-222222222222',
    'VIN-001',
    'REG-001',
    'Volvo',
    'FH16',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);
