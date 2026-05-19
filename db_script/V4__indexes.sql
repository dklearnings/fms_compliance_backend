-- =============================================
-- V4__indexes.sql
-- =============================================

-- =============================================
-- Partial Index:
-- Only DRIVING records
-- =============================================

CREATE INDEX idx_activity_driving_only
ON fms.activity_records (driver_id, started_at)
WHERE activity_type = 'DRIVING';

-- =============================================
-- Composite Index for:
-- Driver + Date Range queries
-- ordered by started_at
-- =============================================

CREATE INDEX idx_activity_driver_date
ON fms.activity_records
(
    driver_id,
    started_at,
    ended_at
);

-- =============================================
-- Compliance lookup indexes
-- =============================================

CREATE INDEX idx_compliance_runs_driver_period
ON fms.compliance_runs
(
    driver_id,
    period_start,
    period_end
);

CREATE INDEX idx_violations_driver_detected
ON fms.compliance_violations
(
    driver_id,
    detected_at DESC
);