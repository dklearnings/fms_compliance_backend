-- =============================================
-- V3__constraints_and_temporal_rules.sql
-- =============================================

-- =============================================
-- Ensure ended_at > started_at
-- =============================================

ALTER TABLE fms.activity_records
ADD CONSTRAINT chk_activity_time_valid
CHECK (ended_at > started_at);

-- =============================================
-- Idempotency Constraint
-- Unique source event per driver
-- =============================================

ALTER TABLE fms.activity_records
ADD CONSTRAINT uq_activity_driver_source
UNIQUE (driver_id, source_reference);

-- =============================================
-- Prevent overlapping activity windows
-- per driver
-- =============================================

ALTER TABLE fms.activity_records
ADD CONSTRAINT ex_activity_no_overlap
EXCLUDE USING gist
(
    driver_id WITH =,
    tstzrange(started_at, ended_at, '[)') WITH &&
);

-- =============================================
-- Ensure compliance period valid
-- =============================================

ALTER TABLE fms.compliance_runs
ADD CONSTRAINT chk_compliance_run_period
CHECK (period_end > period_start);

ALTER TABLE  fms.compliance_violations
ADD CONSTRAINT chk_violation_period
CHECK (period_end > period_start);