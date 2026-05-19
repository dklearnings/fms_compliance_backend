-- =============================================
-- V5__online_add_odometer_column.sql
-- =============================================

-- STEP 1:
-- Add nullable column first
-- metadata-only operation
-- very fast

ALTER TABLE fms.activity_records
ADD COLUMN odometer_km NUMERIC(10,2);

-- STEP 2:
-- Set default for future inserts
-- metadata-only

ALTER TABLE fms.activity_records
ALTER COLUMN odometer_km
SET DEFAULT 0;

-- STEP 3:
-- Backfill existing rows in batches
-- (example shown as one statement)

UPDATE fms.activity_records
SET odometer_km = 0
WHERE odometer_km IS NULL;

-- STEP 4:
-- Add NOT NULL after backfill

ALTER TABLE fms.activity_records
ALTER COLUMN odometer_km
SET NOT NULL;