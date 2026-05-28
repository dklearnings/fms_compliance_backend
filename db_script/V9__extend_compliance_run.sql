-- =========================================================
-- V9__extend_compliance_runs.sql
-- =========================================================

CREATE TYPE compliance_run_type_enum AS ENUM
(
    'SCHEDULED',
    'MANUAL',
    'REPROCESS'
);

ALTER TABLE fms.compliance_runs
ADD COLUMN run_type compliance_run_type_enum
NOT NULL
DEFAULT 'SCHEDULED';

ALTER TABLE fms.compliance_runs
ADD COLUMN error_message TEXT;

ALTER TABLE fms.compliance_runs
ADD COLUMN superseded_run_id UUID;

ALTER TABLE fms.compliance_runs
ADD COLUMN status varchar(100);