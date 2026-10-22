-- =============================================================================
-- Script : 00_Database_Setup.sql
-- Layer  : Infrastructure
-- Purpose: Create the project database and verify its configuration.
--
-- Before running 02_Load_Raw_Data.sql, LOCAL INFILE must be enabled on BOTH
-- the server and the client.
-- =============================================================================

-- Create the database if it does not already exist.
CREATE DATABASE IF NOT EXISTS olist_acquisition_revenue_analytics
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Switch to the project database.
USE olist_acquisition_revenue_analytics;

-- Confirm the active database.
SELECT DATABASE() AS current_database;

-- Confirm schema character set and collation.
SELECT SCHEMA_NAME,
       DEFAULT_CHARACTER_SET_NAME,
       DEFAULT_COLLATION_NAME
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME = 'olist_acquisition_revenue_analytics';

-- Verify that LOCAL INFILE is enabled on the server (needed for CSV loading).
SHOW VARIABLES LIKE 'local_infile';
