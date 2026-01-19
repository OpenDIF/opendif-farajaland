-- Migration: Create audit_db and audit_logs table
-- Date: 2026-01-19
-- Description: Creates the audit_db database and the audit_logs table for the audit service.

SELECT 'CREATE DATABASE audit_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'audit_db')\gexec

\c audit_db

CREATE TABLE IF NOT EXISTS audit_logs (
    id uuid PRIMARY KEY,
    "timestamp" timestamp with time zone NOT NULL,
    trace_id text,
    status character varying(20) NOT NULL,
    event_type character varying(50),
    event_action character varying(50),
    actor_type character varying(50) NOT NULL,
    actor_id character varying(255) NOT NULL,
    target_type character varying(50) NOT NULL,
    target_id character varying(255),
    request_metadata text,
    response_metadata text,
    additional_metadata text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs (status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs ("timestamp");
CREATE INDEX IF NOT EXISTS idx_audit_logs_trace_id ON audit_logs (trace_id);