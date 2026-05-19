--create database fms_db; 

create schema if not exists fms;

-- =============================================
-- V1__extensions_and_enums.sql
-- =============================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- =============================================
-- Activity Type Enum
-- =============================================

CREATE TYPE activity_type_enum AS ENUM
(
    'DRIVING',
    'REST',
    'WORK',
    'AVAILABLE'
);

-- =============================================
-- Compliance Severity Enum
-- =============================================

CREATE TYPE violation_severity_enum AS ENUM
(
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL'
);

-- =============================================
-- Compliance Run Status Enum
-- =============================================

CREATE TYPE compliance_run_status_enum AS ENUM
(
    'PENDING',
    'RUNNING',
    'COMPLETED',
    'FAILED'
);

-- =============================================
-- Violation Type Enum
-- =============================================

CREATE TYPE violation_type_enum AS ENUM
(
    'DAILY_DRIVING_LIMIT',
    'WEEKLY_DRIVING_LIMIT',
    'INSUFFICIENT_REST',
    'MISSING_BREAK',
    'EXCESS_CONTINUOUS_DRIVING'
);