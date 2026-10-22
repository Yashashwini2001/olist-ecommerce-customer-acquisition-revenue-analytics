-- =============================================================================
-- Script : 10_Post_Cleaning_Validation.sql
-- Layer  : Cleaned
-- Purpose: Prove that cleaning (script 07) changed only what the documented
--          rules say it should, before any business analysis is built on it.
-- Gate   : Analysis (script 09) should run only if overall_status is PASS.
--
-- Severity (same meaning as script 04)
--   CRITICAL = cleaning lost, invented or corrupted data. Blocks analysis.
--   REVIEW   = source anomaly carried through (flagged, not removed).
--   INFO     = coverage fact the analysis must respect.
-- Run the whole script in ONE session (it uses temporary tables).
-- Expected values are always derived from stg_*, never hard-coded.
-- =============================================================================
USE olist_acquisition_revenue_analytics;
-- =============================================================================
-- 01. ROW COUNTS: every cleaned table equals its staging table, except the one
--     documented removal (reviews: one per order).
-- =============================================================================
CREATE TEMPORARY TABLE tmp_rowcount_checks AS
SELECT t.table_name, t.stg_rows, t.expected_rows, t.cln_rows,
       CASE WHEN t.expected_rows = t.cln_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'customers' AS table_name,
           (SELECT COUNT(*) FROM stg_customers) AS stg_rows,
           (SELECT COUNT(*) FROM stg_customers) AS expected_rows,
           (SELECT COUNT(*) FROM cln_customers) AS cln_rows
    UNION ALL SELECT 'sellers', (SELECT COUNT(*) FROM stg_sellers), (SELECT COUNT(*) FROM stg_sellers), (SELECT COUNT(*) FROM cln_sellers)
    UNION ALL SELECT 'product_category_translation', (SELECT COUNT(*) FROM stg_product_category_translation), (SELECT COUNT(*) FROM stg_product_category_translation), (SELECT COUNT(*) FROM cln_product_category_translation)
    UNION ALL SELECT 'products', (SELECT COUNT(*) FROM stg_products), (SELECT COUNT(*) FROM stg_products), (SELECT COUNT(*) FROM cln_products)
    UNION ALL SELECT 'orders', (SELECT COUNT(*) FROM stg_orders), (SELECT COUNT(*) FROM stg_orders), (SELECT COUNT(*) FROM cln_orders)
    UNION ALL SELECT 'order_items', (SELECT COUNT(*) FROM stg_order_items), (SELECT COUNT(*) FROM stg_order_items), (SELECT COUNT(*) FROM cln_order_items)
    UNION ALL SELECT 'order_payments', (SELECT COUNT(*) FROM stg_order_payments), (SELECT COUNT(*) FROM stg_order_payments), (SELECT COUNT(*) FROM cln_order_payments)
    -- reviews: exactly one row per distinct order_id (rule R07)
    UNION ALL SELECT 'order_reviews', (SELECT COUNT(*) FROM stg_order_reviews),
                     (SELECT COUNT(DISTINCT TRIM(order_id)) FROM stg_order_reviews),
                     (SELECT COUNT(*) FROM cln_order_reviews)
    UNION ALL SELECT 'geolocation', (SELECT COUNT(*) FROM stg_geolocation), (SELECT COUNT(*) FROM stg_geolocation), (SELECT COUNT(*) FROM cln_geolocation)
    UNION ALL SELECT 'marketing_qualified_leads', (SELECT COUNT(*) FROM stg_marketing_qualified_leads), (SELECT COUNT(*) FROM stg_marketing_qualified_leads), (SELECT COUNT(*) FROM cln_marketing_qualified_leads)
    UNION ALL SELECT 'closed_deals', (SELECT COUNT(*) FROM stg_closed_deals), (SELECT COUNT(*) FROM stg_closed_deals), (SELECT COUNT(*) FROM cln_closed_deals)
) AS t;

SELECT table_name, stg_rows, expected_rows, cln_rows, status
FROM tmp_rowcount_checks
ORDER BY table_name;

-- =============================================================================
-- 02. NO VALUE LOST IN TYPE CONVERSION
-- A cast that fails silently would turn a real value into NULL. For every
-- converted column: (non-blank values in stg) must equal (non-NULL in cln).
-- =============================================================================
CREATE TEMPORARY TABLE tmp_cast_checks AS
SELECT c.check_name, c.stg_non_blank, c.cln_non_null,
       CASE WHEN c.stg_non_blank = c.cln_non_null THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'orders.purchase_ts' AS check_name,
           (SELECT COUNT(*) FROM stg_orders WHERE TRIM(order_purchase_timestamp) <> '') AS stg_non_blank,
           (SELECT COUNT(purchase_ts) FROM cln_orders) AS cln_non_null
    UNION ALL SELECT 'orders.approved_ts', (SELECT COUNT(*) FROM stg_orders WHERE TRIM(order_approved_at) <> ''), (SELECT COUNT(approved_ts) FROM cln_orders)
    UNION ALL SELECT 'orders.delivered_carrier_ts', (SELECT COUNT(*) FROM stg_orders WHERE TRIM(order_delivered_carrier_date) <> ''), (SELECT COUNT(delivered_carrier_ts) FROM cln_orders)
    UNION ALL SELECT 'orders.delivered_customer_ts', (SELECT COUNT(*) FROM stg_orders WHERE TRIM(order_delivered_customer_date) <> ''), (SELECT COUNT(delivered_customer_ts) FROM cln_orders)
    UNION ALL SELECT 'orders.estimated_delivery_ts', (SELECT COUNT(*) FROM stg_orders WHERE TRIM(order_estimated_delivery_date) <> ''), (SELECT COUNT(estimated_delivery_ts) FROM cln_orders)
    UNION ALL SELECT 'order_items.shipping_limit_ts', (SELECT COUNT(*) FROM stg_order_items WHERE TRIM(shipping_limit_date) <> ''), (SELECT COUNT(shipping_limit_ts) FROM cln_order_items)
    UNION ALL SELECT 'order_items.price', (SELECT COUNT(*) FROM stg_order_items WHERE TRIM(price) <> ''), (SELECT COUNT(price) FROM cln_order_items)
    UNION ALL SELECT 'order_items.freight_value', (SELECT COUNT(*) FROM stg_order_items WHERE TRIM(freight_value) <> ''), (SELECT COUNT(freight_value) FROM cln_order_items)
    UNION ALL SELECT 'order_payments.payment_value', (SELECT COUNT(*) FROM stg_order_payments WHERE TRIM(payment_value) <> ''), (SELECT COUNT(payment_value) FROM cln_order_payments)
    UNION ALL SELECT 'order_payments.payment_installments', (SELECT COUNT(*) FROM stg_order_payments WHERE TRIM(payment_installments) <> ''), (SELECT COUNT(payment_installments) FROM cln_order_payments)
    -- reviews: compare only the surviving rows' columns against all stg orders
    UNION ALL SELECT 'order_reviews.review_score (one per order)', (SELECT COUNT(DISTINCT TRIM(order_id)) FROM stg_order_reviews WHERE TRIM(review_score) <> ''), (SELECT COUNT(review_score) FROM cln_order_reviews)
    UNION ALL SELECT 'products.weight_g (zeros become NULL by rule R05)', (SELECT COUNT(*) FROM stg_products WHERE TRIM(product_weight_g) NOT IN ('', '0')), (SELECT COUNT(weight_g) FROM cln_products)
    UNION ALL SELECT 'products.photos_qty', (SELECT COUNT(*) FROM stg_products WHERE TRIM(product_photos_qty) <> ''), (SELECT COUNT(photos_qty) FROM cln_products)
    UNION ALL SELECT 'geolocation.lat', (SELECT COUNT(*) FROM stg_geolocation WHERE TRIM(geolocation_lat) <> ''), (SELECT COUNT(lat) FROM cln_geolocation)
    UNION ALL SELECT 'geolocation.lng', (SELECT COUNT(*) FROM stg_geolocation WHERE TRIM(geolocation_lng) <> ''), (SELECT COUNT(lng) FROM cln_geolocation)
    UNION ALL SELECT 'marketing_qualified_leads.first_contact_date', (SELECT COUNT(*) FROM stg_marketing_qualified_leads WHERE TRIM(first_contact_date) <> ''), (SELECT COUNT(first_contact_date) FROM cln_marketing_qualified_leads)
    UNION ALL SELECT 'closed_deals.won_ts', (SELECT COUNT(*) FROM stg_closed_deals WHERE TRIM(won_date) <> ''), (SELECT COUNT(won_ts) FROM cln_closed_deals)
    UNION ALL SELECT 'closed_deals.declared_monthly_revenue', (SELECT COUNT(*) FROM stg_closed_deals WHERE TRIM(declared_monthly_revenue) <> ''), (SELECT COUNT(declared_monthly_revenue) FROM cln_closed_deals)
) AS c;

SELECT check_name, stg_non_blank, cln_non_null, status
FROM tmp_cast_checks
ORDER BY check_name;

-- =============================================================================
-- 03. MONEY AND SCORE TOTALS STILL RECONCILE
-- The cleaned totals must equal the totals computed straight from stg text.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_value_checks AS
SELECT v.check_name, v.stg_total, v.cln_total,
       CASE WHEN v.stg_total = v.cln_total THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'SUM(order_items.price)' AS check_name,
           (SELECT ROUND(SUM(CAST(price AS DECIMAL(12, 2))), 2) FROM stg_order_items) AS stg_total,
           (SELECT ROUND(SUM(price), 2) FROM cln_order_items) AS cln_total
    UNION ALL SELECT 'SUM(order_items.freight_value)',
           (SELECT ROUND(SUM(CAST(freight_value AS DECIMAL(12, 2))), 2) FROM stg_order_items),
           (SELECT ROUND(SUM(freight_value), 2) FROM cln_order_items)
    UNION ALL SELECT 'SUM(order_payments.payment_value)',
           (SELECT ROUND(SUM(CAST(payment_value AS DECIMAL(12, 2))), 2) FROM stg_order_payments),
           (SELECT ROUND(SUM(payment_value), 2) FROM cln_order_payments)
    UNION ALL SELECT 'COUNT(orders with status delivered)',
           (SELECT COUNT(*) FROM stg_orders WHERE TRIM(order_status) = 'delivered'),
           (SELECT COUNT(*) FROM cln_orders WHERE order_status = 'delivered')
    UNION ALL SELECT 'COUNT(distinct sellers in order_items)',
           (SELECT COUNT(DISTINCT TRIM(seller_id)) FROM stg_order_items),
           (SELECT COUNT(DISTINCT seller_id) FROM cln_order_items)
) AS v;

SELECT check_name, stg_total, cln_total, status
FROM tmp_value_checks
ORDER BY check_name;

-- =============================================================================
-- 04. RELATIONSHIPS STILL INTACT (child rows with no parent)
-- =============================================================================
CREATE TEMPORARY TABLE tmp_integrity_checks AS
SELECT 'order_items -> orders' AS relationship, COUNT(*) AS orphan_rows
FROM cln_order_items AS i LEFT JOIN cln_orders AS o ON o.order_id = i.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'order_items -> products', COUNT(*)
FROM cln_order_items AS i LEFT JOIN cln_products AS p ON p.product_id = i.product_id WHERE p.product_id IS NULL
UNION ALL SELECT 'order_items -> sellers', COUNT(*)
FROM cln_order_items AS i LEFT JOIN cln_sellers AS s ON s.seller_id = i.seller_id WHERE s.seller_id IS NULL
UNION ALL SELECT 'orders -> customers', COUNT(*)
FROM cln_orders AS o LEFT JOIN cln_customers AS c ON c.customer_id = o.customer_id WHERE c.customer_id IS NULL
UNION ALL SELECT 'order_payments -> orders', COUNT(*)
FROM cln_order_payments AS p LEFT JOIN cln_orders AS o ON o.order_id = p.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'order_reviews -> orders', COUNT(*)
FROM cln_order_reviews AS r LEFT JOIN cln_orders AS o ON o.order_id = r.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'closed_deals -> marketing_qualified_leads', COUNT(*)
FROM cln_closed_deals AS d LEFT JOIN cln_marketing_qualified_leads AS l ON l.mql_id = d.mql_id WHERE l.mql_id IS NULL;

SELECT relationship, orphan_rows, CASE WHEN orphan_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM tmp_integrity_checks
ORDER BY relationship;

-- =============================================================================
-- 05. NO EMPTY OR PADDED TEXT LEFT, AND DOMAINS ARE VALID
-- Generated from information_schema so every text column of every cln_ table
-- is covered. Expected: 0 everywhere.
-- =============================================================================
SET SESSION group_concat_max_len = 4000000;

SELECT GROUP_CONCAT(
         CONCAT('SELECT ''', TABLE_NAME, '.', COLUMN_NAME, ''' AS check_name, ',
                'SUM(`', COLUMN_NAME, '` = '''' OR CHAR_LENGTH(`', COLUMN_NAME, '`) <> CHAR_LENGTH(TRIM(`', COLUMN_NAME, '`))) AS bad_values ',
                'FROM `', TABLE_NAME, '`')
         ORDER BY TABLE_NAME, ORDINAL_POSITION SEPARATOR ' UNION ALL ')
INTO @blank_sql
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'cln\_%'
  AND DATA_TYPE IN ('varchar', 'char', 'text');

SET @blank_sql = CONCAT('CREATE TEMPORARY TABLE tmp_blank_checks AS ', @blank_sql);
PREPARE blank_stmt FROM @blank_sql;
EXECUTE blank_stmt;
DEALLOCATE PREPARE blank_stmt;

INSERT INTO tmp_blank_checks
SELECT 'order_reviews.review_score outside 1-5', COUNT(*) FROM cln_order_reviews WHERE review_score NOT BETWEEN 1 AND 5
UNION ALL SELECT 'order_items.price or freight negative', COUNT(*) FROM cln_order_items WHERE price < 0 OR freight_value < 0
UNION ALL SELECT 'order_payments.payment_value negative', COUNT(*) FROM cln_order_payments WHERE payment_value < 0;

SELECT COUNT(*) AS columns_checked, SUM(bad_values > 0) AS columns_with_bad_values, SUM(bad_values) AS total_bad_values
FROM tmp_blank_checks;

-- =============================================================================
-- 06. QUALITY SCORECARD - completeness of every cleaned column
-- (data quality layer 5). Lists only columns that are not 100% populated.
-- Missing is not an error; it tells the analysis which fields it cannot lean on.
-- =============================================================================
SET SESSION group_concat_max_len = 4000000;

SELECT GROUP_CONCAT(
         CONCAT('SELECT ''', TABLE_NAME, ''' AS table_name, ''', COLUMN_NAME, ''' AS column_name, ',
                'COUNT(*) AS total_rows, COUNT(`', COLUMN_NAME, '`) AS populated_rows ',
                'FROM `', TABLE_NAME, '`')
         ORDER BY TABLE_NAME, ORDINAL_POSITION SEPARATOR ' UNION ALL ')
INTO @score_sql
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'cln\_%';

SET @score_sql = CONCAT(
  'SELECT table_name, column_name, total_rows, populated_rows, ',
  'ROUND(100 * populated_rows / total_rows, 1) AS completeness_pct ',
  'FROM (', @score_sql, ') AS s WHERE populated_rows < total_rows ',
  'ORDER BY completeness_pct, table_name, column_name');
PREPARE score_stmt FROM @score_sql;
EXECUTE score_stmt;
DEALLOCATE PREPARE score_stmt;

-- =============================================================================
-- 07. ROLLUP AND GATE
-- =============================================================================
CREATE TEMPORARY TABLE tmp_validation_rollup (
    severity      VARCHAR(10)  NOT NULL,
    finding       VARCHAR(120) NOT NULL,
    measure       VARCHAR(20)  NOT NULL,
    finding_count BIGINT       NOT NULL
);

INSERT INTO tmp_validation_rollup SELECT 'CRITICAL', 'row counts reconcile to staging',          'failed checks', COUNT(*) FROM tmp_rowcount_checks  WHERE status = 'FAIL';
INSERT INTO tmp_validation_rollup SELECT 'CRITICAL', 'no value lost in type conversion',         'failed checks', COUNT(*) FROM tmp_cast_checks      WHERE status = 'FAIL';
INSERT INTO tmp_validation_rollup SELECT 'CRITICAL', 'money and count totals reconcile',         'failed checks', COUNT(*) FROM tmp_value_checks     WHERE status = 'FAIL';
INSERT INTO tmp_validation_rollup SELECT 'CRITICAL', 'relationships intact after cleaning',      'failed checks', COUNT(*) FROM tmp_integrity_checks WHERE orphan_rows > 0;
INSERT INTO tmp_validation_rollup SELECT 'CRITICAL', 'no empty / padded text, valid domains',    'failed checks', COUNT(*) FROM tmp_blank_checks     WHERE bad_values > 0;

-- Flags carried through from the source (must equal what script 04 reported)
INSERT INTO tmp_validation_rollup SELECT 'REVIEW', 'carrier date before purchase (flagged)',          'records', SUM(flag_carrier_before_purchase) FROM cln_orders;
INSERT INTO tmp_validation_rollup SELECT 'REVIEW', 'delivered but no delivery date (flagged)',        'records', SUM(flag_delivered_without_date)  FROM cln_orders;
INSERT INTO tmp_validation_rollup SELECT 'REVIEW', 'not delivered but has delivery date (flagged)',   'records', SUM(flag_nondelivered_with_date)  FROM cln_orders;
INSERT INTO tmp_validation_rollup SELECT 'REVIEW', 'payments with 0 instalments (flagged)',           'records', SUM(flag_zero_installments)       FROM cln_order_payments;
INSERT INTO tmp_validation_rollup SELECT 'REVIEW', 'delivered to customer before purchase',           'records', COUNT(*) FROM cln_orders WHERE delivered_customer_ts < purchase_ts;
INSERT INTO tmp_validation_rollup SELECT 'REVIEW', 'closed deal won before the lead first contact',   'records', COUNT(*)
FROM cln_closed_deals AS d INNER JOIN cln_marketing_qualified_leads AS l ON l.mql_id = d.mql_id
WHERE DATE(d.won_ts) < l.first_contact_date;

-- Coverage facts the analysis must respect
INSERT INTO tmp_validation_rollup SELECT 'INFO', 'orders without any review', 'records', COUNT(*)
FROM cln_orders AS o LEFT JOIN cln_order_reviews AS r ON r.order_id = o.order_id WHERE r.order_id IS NULL;
INSERT INTO tmp_validation_rollup SELECT 'INFO', 'orders without any item (cancelled / unavailable mostly)', 'records', COUNT(*)
FROM cln_orders AS o LEFT JOIN (SELECT DISTINCT order_id FROM cln_order_items) AS i ON i.order_id = o.order_id WHERE i.order_id IS NULL;
INSERT INTO tmp_validation_rollup SELECT 'INFO', 'orders after 2018-08-31 (outside the complete-data window)', 'records', COUNT(*)
FROM cln_orders WHERE purchase_ts >= '2018-09-01';
INSERT INTO tmp_validation_rollup SELECT 'INFO', 'orders before 2017-01-01 (sparse 2016 data)', 'records', COUNT(*)
FROM cln_orders WHERE purchase_ts < '2017-01-01';
INSERT INTO tmp_validation_rollup SELECT 'INFO', 'closed deals whose seller is not in the seller table', 'records', COUNT(*)
FROM cln_closed_deals AS d LEFT JOIN cln_sellers AS s ON s.seller_id = d.seller_id WHERE s.seller_id IS NULL;

SELECT severity, finding, measure, finding_count,
       CASE WHEN severity = 'CRITICAL' AND finding_count > 0 THEN 'FAIL'
            WHEN severity = 'CRITICAL'                       THEN 'PASS'
            ELSE severity END AS status
FROM tmp_validation_rollup
ORDER BY FIELD(severity, 'CRITICAL', 'REVIEW', 'INFO'), finding;

SELECT CASE WHEN SUM(severity = 'CRITICAL' AND finding_count > 0) = 0 THEN 'PASS' ELSE 'FAIL' END AS overall_status,
       SUM(severity = 'CRITICAL')                       AS critical_checks_run,
       SUM(severity = 'CRITICAL' AND finding_count > 0) AS critical_checks_failed,
       SUM(severity = 'REVIEW'   AND finding_count > 0) AS review_findings,
       SUM(severity = 'INFO'     AND finding_count > 0) AS info_findings
FROM tmp_validation_rollup;

DROP TEMPORARY TABLE IF EXISTS tmp_rowcount_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_cast_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_value_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_integrity_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_blank_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_validation_rollup;
