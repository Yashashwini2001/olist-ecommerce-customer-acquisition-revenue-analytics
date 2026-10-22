-- =============================================================================
-- Script : 05_Staging_Tables.sql
-- Layer  : Staging
-- Purpose: Create empty stg_* tables in the same project database.
-- Rule   : This script creates structure only. It does not copy or clean data.
--          Raw tables remain the source of truth.
-- =============================================================================
-- =============================================================================
-- 01. DATABASE
-- =============================================================================
USE olist_acquisition_revenue_analytics;
-- =============================================================================
-- 02. REMOVE EXISTING STAGING TABLES
-- =============================================================================
-- Allows controlled re-execution during development and testing.
-- Only staging tables are removed.
-- Raw tables remain unchanged.
DROP 
  TABLE IF EXISTS stg_closed_deals;
DROP 
  TABLE IF EXISTS stg_marketing_qualified_leads;
DROP 
  TABLE IF EXISTS stg_geolocation;
DROP 
  TABLE IF EXISTS stg_order_reviews;
DROP 
  TABLE IF EXISTS stg_order_payments;
DROP 
  TABLE IF EXISTS stg_order_items;
DROP 
  TABLE IF EXISTS stg_orders;
DROP 
  TABLE IF EXISTS stg_products;
DROP 
  TABLE IF EXISTS stg_product_category_translation;
DROP 
  TABLE IF EXISTS stg_sellers;
DROP 
  TABLE IF EXISTS stg_customers;
-- =============================================================================
-- 03. OLIST E-COMMERCE STAGING TABLES
-- =============================================================================
-- Structures are inherited from the corresponding raw tables.
-- No data is copied at this stage.
CREATE TABLE stg_customers LIKE raw_customers;
CREATE TABLE stg_sellers LIKE raw_sellers;
CREATE TABLE stg_product_category_translation LIKE raw_product_category_translation;
CREATE TABLE stg_products LIKE raw_products;
CREATE TABLE stg_orders LIKE raw_orders;
CREATE TABLE stg_order_items LIKE raw_order_items;
CREATE TABLE stg_order_payments LIKE raw_order_payments;
CREATE TABLE stg_order_reviews LIKE raw_order_reviews;
CREATE TABLE stg_geolocation LIKE raw_geolocation;
-- =============================================================================
-- 04. OLIST MARKETING FUNNEL STAGING TABLES
-- =============================================================================
CREATE TABLE stg_marketing_qualified_leads LIKE raw_marketing_qualified_leads;
CREATE TABLE stg_closed_deals LIKE raw_closed_deals;
-- =============================================================================
-- 05. STAGING TABLE EXISTENCE CHECK
-- =============================================================================
-- Confirms that all expected staging tables were created.
-- Expected result: 11 tables.
SELECT 
    COUNT(*) AS staging_tables_created
FROM
    information_schema.tables
WHERE
    table_schema = DATABASE()
        AND table_name IN ('stg_customers' , 'stg_sellers',
        'stg_product_category_translation',
        'stg_products',
        'stg_orders',
        'stg_order_items',
        'stg_order_payments',
        'stg_order_reviews',
        'stg_geolocation',
        'stg_marketing_qualified_leads',
        'stg_closed_deals');
-- =============================================================================
-- 06. STAGING TABLE LIST
-- =============================================================================
-- Provides an auditable list of the staging structures created.
SELECT 
    table_name
FROM
    information_schema.tables
WHERE
    table_schema = DATABASE()
        AND table_name IN ('stg_customers' , 'stg_sellers',
        'stg_product_category_translation',
        'stg_products',
        'stg_orders',
        'stg_order_items',
        'stg_order_payments',
        'stg_order_reviews',
        'stg_geolocation',
        'stg_marketing_qualified_leads',
        'stg_closed_deals')
ORDER BY table_name;
-- =============================================================================
-- 07. STAGING ROW-COUNT CHECK
-- =============================================================================
-- Confirms that the newly created staging tables contain no records.
-- Data loading is intentionally handled by the next SQL script.
SELECT 
    'stg_customers' AS table_name, COUNT(*) AS row_count
FROM
    stg_customers 
UNION ALL SELECT 
    'stg_sellers', COUNT(*)
FROM
    stg_sellers 
UNION ALL SELECT 
    'stg_product_category_translation', COUNT(*)
FROM
    stg_product_category_translation 
UNION ALL SELECT 
    'stg_products', COUNT(*)
FROM
    stg_products 
UNION ALL SELECT 
    'stg_orders', COUNT(*)
FROM
    stg_orders 
UNION ALL SELECT 
    'stg_order_items', COUNT(*)
FROM
    stg_order_items 
UNION ALL SELECT 
    'stg_order_payments', COUNT(*)
FROM
    stg_order_payments 
UNION ALL SELECT 
    'stg_order_reviews', COUNT(*)
FROM
    stg_order_reviews 
UNION ALL SELECT 
    'stg_geolocation', COUNT(*)
FROM
    stg_geolocation 
UNION ALL SELECT 
    'stg_marketing_qualified_leads', COUNT(*)
FROM
    stg_marketing_qualified_leads 
UNION ALL SELECT 
    'stg_closed_deals', COUNT(*)
FROM
    stg_closed_deals
ORDER BY table_name;