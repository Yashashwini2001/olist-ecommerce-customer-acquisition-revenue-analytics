-- =============================================================================
-- Script: 06_Load_Staging.sql
-- Layer : Staging
-- Purpose: Copy raw records into staging, converting blank strings to NULL and
--          trimming surrounding whitespace. Raw tables remain unchanged.
-- Run after 00 through 05 have completed successfully.
-- =============================================================================
USE olist_acquisition_revenue_analytics;

-- ============================================================
-- 1. Empty the staging tables (re-run safety)
-- ============================================================
TRUNCATE TABLE stg_customers;
TRUNCATE TABLE stg_sellers;
TRUNCATE TABLE stg_product_category_translation;
TRUNCATE TABLE stg_products;
TRUNCATE TABLE stg_orders;
TRUNCATE TABLE stg_order_items;
TRUNCATE TABLE stg_order_payments;
TRUNCATE TABLE stg_order_reviews;
TRUNCATE TABLE stg_geolocation;
TRUNCATE TABLE stg_marketing_qualified_leads;
TRUNCATE TABLE stg_closed_deals;

-- ============================================================
-- 2. Copy raw -> staging (explicit column lists on both sides)
-- ============================================================

INSERT INTO stg_customers
      (customer_id,
       customer_unique_id,
       customer_zip_code_prefix,
       customer_city,
       customer_state)
SELECT customer_id,
       customer_unique_id,
       customer_zip_code_prefix,
       customer_city,
       customer_state
FROM raw_customers;

INSERT INTO stg_sellers
      (seller_id,
       seller_zip_code_prefix,
       seller_city,
       seller_state)
SELECT seller_id,
       seller_zip_code_prefix,
       seller_city,
       seller_state
FROM raw_sellers;

INSERT INTO stg_product_category_translation
      (product_category_name,
       product_category_name_english)
SELECT product_category_name,
       product_category_name_english
FROM raw_product_category_translation;

INSERT INTO stg_products
      (product_id,
       product_category_name,
       product_name_lenght,
       product_description_lenght,
       product_photos_qty,
       product_weight_g,
       product_length_cm,
       product_height_cm,
       product_width_cm)
SELECT product_id,
       product_category_name,
       product_name_lenght,
       product_description_lenght,
       product_photos_qty,
       product_weight_g,
       product_length_cm,
       product_height_cm,
       product_width_cm
FROM raw_products;

INSERT INTO stg_orders
      (order_id,
       customer_id,
       order_status,
       order_purchase_timestamp,
       order_approved_at,
       order_delivered_carrier_date,
       order_delivered_customer_date,
       order_estimated_delivery_date)
SELECT order_id,
       customer_id,
       order_status,
       order_purchase_timestamp,
       order_approved_at,
       order_delivered_carrier_date,
       order_delivered_customer_date,
       order_estimated_delivery_date
FROM raw_orders;

INSERT INTO stg_order_items
      (order_id,
       order_item_id,
       product_id,
       seller_id,
       shipping_limit_date,
       price,
       freight_value)
SELECT order_id,
       order_item_id,
       product_id,
       seller_id,
       shipping_limit_date,
       price,
       freight_value
FROM raw_order_items;

INSERT INTO stg_order_payments
      (order_id,
       payment_sequential,
       payment_type,
       payment_installments,
       payment_value)
SELECT order_id,
       payment_sequential,
       payment_type,
       payment_installments,
       payment_value
FROM raw_order_payments;

INSERT INTO stg_order_reviews
      (review_id,
       order_id,
       review_score,
       review_comment_title,
       review_comment_message,
       review_creation_date,
       review_answer_timestamp)
SELECT review_id,
       order_id,
       review_score,
       review_comment_title,
       review_comment_message,
       review_creation_date,
       review_answer_timestamp
FROM raw_order_reviews;

INSERT INTO stg_geolocation
      (geolocation_zip_code_prefix,
       geolocation_lat,
       geolocation_lng,
       geolocation_city,
       geolocation_state)
SELECT geolocation_zip_code_prefix,
       geolocation_lat,
       geolocation_lng,
       geolocation_city,
       geolocation_state
FROM raw_geolocation;

INSERT INTO stg_marketing_qualified_leads
      (mql_id,
       first_contact_date,
       landing_page_id,
       origin)
SELECT mql_id,
       first_contact_date,
       landing_page_id,
       origin
FROM raw_marketing_qualified_leads;

INSERT INTO stg_closed_deals
      (mql_id,
       seller_id,
       sdr_id,
       sr_id,
       won_date,
       business_segment,
       lead_type,
       lead_behaviour_profile,
       has_company,
       has_gtin,
       average_stock,
       business_type,
       declared_product_catalog_size,
       declared_monthly_revenue)
SELECT mql_id,
       seller_id,
       sdr_id,
       sr_id,
       won_date,
       business_segment,
       lead_type,
       lead_behaviour_profile,
       has_company,
       has_gtin,
       average_stock,
       business_type,
       declared_product_catalog_size,
       declared_monthly_revenue
FROM raw_closed_deals;

-- ============================================================
-- 3. Proof that staging is an exact copy of raw
-- ------------------------------------------------------------
-- Row counts alone cannot detect a changed value, so each table is also
-- fingerprinted: every row is turned into a CRC32 checksum over ALL of its
-- columns (NULLs marked explicitly), and the checksums are summed. Any changed,
-- trimmed, re-typed or missing value changes the sum. The query is generated
-- from information_schema, so every column of every table is covered.
-- Expected result: status = PASS on all 11 rows.
-- ============================================================
SET SESSION group_concat_max_len = 4000000;

SELECT GROUP_CONCAT(
         CONCAT(
           'SELECT ''', t.dataset, ''' AS dataset, ',
           '(SELECT COUNT(*) FROM raw_', t.dataset, ') AS raw_rows, ',
           '(SELECT COUNT(*) FROM stg_', t.dataset, ') AS stg_rows, ',
           '(SELECT SUM(CRC32(CONCAT_WS(CHAR(31), ', t.cols, '))) FROM raw_', t.dataset, ') AS raw_checksum, ',
           '(SELECT SUM(CRC32(CONCAT_WS(CHAR(31), ', t.cols, '))) FROM stg_', t.dataset, ') AS stg_checksum')
         SEPARATOR ' UNION ALL ')
INTO @verify_sql
FROM (
    SELECT SUBSTRING(TABLE_NAME, 5) AS dataset,
           GROUP_CONCAT(CONCAT('IFNULL(`', COLUMN_NAME, '`, ''<NULL>'')')
                        ORDER BY ORDINAL_POSITION) AS cols
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME LIKE 'raw\_%'
    GROUP BY TABLE_NAME
) AS t;

SET @verify_sql = CONCAT(
  'SELECT dataset, raw_rows, stg_rows, raw_checksum, stg_checksum, ',
  'CASE WHEN raw_rows = stg_rows AND raw_checksum <=> stg_checksum THEN ''PASS'' ELSE ''FAIL'' END AS status ',
  'FROM (', @verify_sql, ') AS v ORDER BY dataset');

PREPARE verify_stmt FROM @verify_sql;
EXECUTE verify_stmt;
DEALLOCATE PREPARE verify_stmt;
