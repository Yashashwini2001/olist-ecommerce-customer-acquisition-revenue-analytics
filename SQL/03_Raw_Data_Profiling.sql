-- =============================================================================
-- Script : 03_Raw_Data_Profiling.sql
-- Layer  : Raw
-- Purpose: Profile loaded raw data before validation and staging.
-- Rule   : Observation only; no cleaning, casting, standardization, or
--          transformation is performed on raw data.
-- =============================================================================
USE olist_acquisition_revenue_analytics;

-- ============================================================
-- 1. Table row counts
-- Confirm the number of rows loaded into every raw table.
-- ============================================================
SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count FROM raw_customers
UNION ALL SELECT 'raw_sellers',                      COUNT(*) FROM raw_sellers
UNION ALL SELECT 'raw_product_category_translation', COUNT(*) FROM raw_product_category_translation
UNION ALL SELECT 'raw_products',                     COUNT(*) FROM raw_products
UNION ALL SELECT 'raw_orders',                       COUNT(*) FROM raw_orders
UNION ALL SELECT 'raw_order_items',                  COUNT(*) FROM raw_order_items
UNION ALL SELECT 'raw_order_payments',               COUNT(*) FROM raw_order_payments
UNION ALL SELECT 'raw_order_reviews',                COUNT(*) FROM raw_order_reviews
UNION ALL SELECT 'raw_geolocation',                  COUNT(*) FROM raw_geolocation
UNION ALL SELECT 'raw_marketing_qualified_leads',    COUNT(*) FROM raw_marketing_qualified_leads
UNION ALL SELECT 'raw_closed_deals',                 COUNT(*) FROM raw_closed_deals
ORDER BY table_name;

-- ============================================================
-- 2. Table / column metadata
-- Inspect the schema of every raw table.
-- ============================================================
SELECT TABLE_NAME,
       ORDINAL_POSITION,
       COLUMN_NAME,
       DATA_TYPE,
       CHARACTER_MAXIMUM_LENGTH,
       IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'raw\_%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ============================================================
-- 3. NULL / blank / padded-value counts - EVERY column of EVERY raw table
-- ------------------------------------------------------------
--   null_count   : true SQL NULLs
--   blank_count  : empty string or whitespace only (TRIM(value) = '')
--   padded_count : non-blank values with leading/trailing spaces
--                  (tells us whether TRIM would change anything later)
-- ============================================================
SET SESSION group_concat_max_len = 4000000;

SELECT GROUP_CONCAT(
         CONCAT(
           'SELECT ''', TABLE_NAME, ''' AS table_name, ',
                  '''', COLUMN_NAME, ''' AS column_name, ',
           'COUNT(*) AS total_rows, ',
           'SUM(`', COLUMN_NAME, '` IS NULL) AS null_count, ',
           'SUM(TRIM(`', COLUMN_NAME, '`) = '''') AS blank_count, ',
           'SUM(TRIM(`', COLUMN_NAME, '`) <> '''' AND ',
               'CHAR_LENGTH(`', COLUMN_NAME, '`) <> CHAR_LENGTH(TRIM(`', COLUMN_NAME, '`))) AS padded_count ',
           'FROM `', TABLE_NAME, '`')
         ORDER BY TABLE_NAME, ORDINAL_POSITION
         SEPARATOR ' UNION ALL ')
INTO @profile_sql
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'raw\_%';

SET @profile_sql = CONCAT(
  'SELECT table_name, column_name, total_rows, null_count, blank_count, padded_count, ',
  'ROUND(100 * (null_count + blank_count) / total_rows, 2) AS missing_pct ',
  'FROM (', @profile_sql, ') AS p ',
  'WHERE null_count + blank_count + padded_count > 0 ',
  'ORDER BY null_count + blank_count DESC, table_name, column_name');

PREPARE profile_stmt FROM @profile_sql;
EXECUTE profile_stmt;
DEALLOCATE PREPARE profile_stmt;

-- ============================================================
-- 4. Distinct counts - key business columns
-- NULL-safe: blank values are excluded before counting.
-- distinct_count < non_blank_rows means the column repeats (not a unique key).
-- ============================================================
SELECT 'raw_customers' AS table_name, 'customer_id' AS column_name,
       COUNT(NULLIF(TRIM(customer_id), '')) AS non_blank_rows,
       COUNT(DISTINCT NULLIF(TRIM(customer_id), '')) AS distinct_count
FROM raw_customers
UNION ALL SELECT 'raw_customers', 'customer_unique_id',
       COUNT(NULLIF(TRIM(customer_unique_id), '')), COUNT(DISTINCT NULLIF(TRIM(customer_unique_id), ''))
FROM raw_customers
UNION ALL SELECT 'raw_sellers', 'seller_id',
       COUNT(NULLIF(TRIM(seller_id), '')), COUNT(DISTINCT NULLIF(TRIM(seller_id), ''))
FROM raw_sellers
UNION ALL SELECT 'raw_products', 'product_id',
       COUNT(NULLIF(TRIM(product_id), '')), COUNT(DISTINCT NULLIF(TRIM(product_id), ''))
FROM raw_products
UNION ALL SELECT 'raw_orders', 'order_id',
       COUNT(NULLIF(TRIM(order_id), '')), COUNT(DISTINCT NULLIF(TRIM(order_id), ''))
FROM raw_orders
UNION ALL SELECT 'raw_order_items', 'order_id',
       COUNT(NULLIF(TRIM(order_id), '')), COUNT(DISTINCT NULLIF(TRIM(order_id), ''))
FROM raw_order_items
UNION ALL SELECT 'raw_order_items', 'seller_id',
       COUNT(NULLIF(TRIM(seller_id), '')), COUNT(DISTINCT NULLIF(TRIM(seller_id), ''))
FROM raw_order_items
UNION ALL SELECT 'raw_order_payments', 'order_id',
       COUNT(NULLIF(TRIM(order_id), '')), COUNT(DISTINCT NULLIF(TRIM(order_id), ''))
FROM raw_order_payments
UNION ALL SELECT 'raw_order_reviews', 'review_id',
       COUNT(NULLIF(TRIM(review_id), '')), COUNT(DISTINCT NULLIF(TRIM(review_id), ''))
FROM raw_order_reviews
UNION ALL SELECT 'raw_order_reviews', 'order_id',
       COUNT(NULLIF(TRIM(order_id), '')), COUNT(DISTINCT NULLIF(TRIM(order_id), ''))
FROM raw_order_reviews
UNION ALL SELECT 'raw_marketing_qualified_leads', 'mql_id',
       COUNT(NULLIF(TRIM(mql_id), '')), COUNT(DISTINCT NULLIF(TRIM(mql_id), ''))
FROM raw_marketing_qualified_leads
UNION ALL SELECT 'raw_closed_deals', 'mql_id',
       COUNT(NULLIF(TRIM(mql_id), '')), COUNT(DISTINCT NULLIF(TRIM(mql_id), ''))
FROM raw_closed_deals
UNION ALL SELECT 'raw_closed_deals', 'seller_id',
       COUNT(NULLIF(TRIM(seller_id), '')), COUNT(DISTINCT NULLIF(TRIM(seller_id), ''))
FROM raw_closed_deals
ORDER BY table_name, column_name;

-- ============================================================
-- 5. Duplicate observations - business keys and composite grains
-- duplicate_key_groups : keys that appear more than once
-- extra_rows           : rows beyond the first occurrence of each key
-- NULL-safe: NULL / blank keys are excluded before grouping.
-- ============================================================
SELECT 'raw_customers' AS table_name, 'customer_id' AS key_definition,
       COUNT(*) AS duplicate_key_groups, COALESCE(SUM(n - 1), 0) AS extra_rows
FROM (SELECT customer_id, COUNT(*) AS n FROM raw_customers
      WHERE customer_id IS NOT NULL AND TRIM(customer_id) <> ''
      GROUP BY customer_id HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_sellers', 'seller_id', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT seller_id, COUNT(*) AS n FROM raw_sellers
      WHERE seller_id IS NOT NULL AND TRIM(seller_id) <> ''
      GROUP BY seller_id HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_products', 'product_id', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT product_id, COUNT(*) AS n FROM raw_products
      WHERE product_id IS NOT NULL AND TRIM(product_id) <> ''
      GROUP BY product_id HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_orders', 'order_id', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT order_id, COUNT(*) AS n FROM raw_orders
      WHERE order_id IS NOT NULL AND TRIM(order_id) <> ''
      GROUP BY order_id HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_order_items', '(order_id, order_item_id)', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT order_id, order_item_id, COUNT(*) AS n FROM raw_order_items
      WHERE order_id IS NOT NULL AND TRIM(order_id) <> ''
        AND order_item_id IS NOT NULL AND TRIM(order_item_id) <> ''
      GROUP BY order_id, order_item_id HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_order_payments', '(order_id, payment_sequential)', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT order_id, payment_sequential, COUNT(*) AS n FROM raw_order_payments
      WHERE order_id IS NOT NULL AND TRIM(order_id) <> ''
        AND payment_sequential IS NOT NULL AND TRIM(payment_sequential) <> ''
      GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_order_reviews', 'review_id', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT review_id, COUNT(*) AS n FROM raw_order_reviews
      WHERE review_id IS NOT NULL AND TRIM(review_id) <> ''
      GROUP BY review_id HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_marketing_qualified_leads', 'mql_id', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT mql_id, COUNT(*) AS n FROM raw_marketing_qualified_leads
      WHERE mql_id IS NOT NULL AND TRIM(mql_id) <> ''
      GROUP BY mql_id HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'raw_closed_deals', 'mql_id', COUNT(*), COALESCE(SUM(n - 1), 0)
FROM (SELECT mql_id, COUNT(*) AS n FROM raw_closed_deals
      WHERE mql_id IS NOT NULL AND TRIM(mql_id) <> ''
      GROUP BY mql_id HAVING COUNT(*) > 1) AS d
ORDER BY table_name, key_definition;

-- ============================================================
-- 6. Categorical distributions
-- Frequency of every controlled / low-cardinality field.
-- ============================================================
SELECT order_status, COUNT(*) AS row_count
FROM raw_orders
GROUP BY order_status
ORDER BY row_count DESC;

SELECT payment_type, COUNT(*) AS row_count
FROM raw_order_payments
GROUP BY payment_type
ORDER BY row_count DESC;

SELECT review_score, COUNT(*) AS row_count
FROM raw_order_reviews
GROUP BY review_score
ORDER BY review_score;

-- Marketing funnel: where do leads come from, and which segments close?
SELECT origin, COUNT(*) AS lead_count
FROM raw_marketing_qualified_leads
GROUP BY origin
ORDER BY lead_count DESC;

SELECT business_segment, COUNT(*) AS closed_deal_count
FROM raw_closed_deals
GROUP BY business_segment
ORDER BY closed_deal_count DESC;

-- ============================================================
-- 7. Date-value boundaries
-- Dates are ISO-formatted text, so MIN/MAX sort correctly as text.
-- ============================================================
SELECT 'raw_orders.order_purchase_timestamp' AS column_name,
       MIN(NULLIF(TRIM(order_purchase_timestamp), '')) AS min_value,
       MAX(NULLIF(TRIM(order_purchase_timestamp), '')) AS max_value,
       COUNT(NULLIF(TRIM(order_purchase_timestamp), '')) AS non_blank_count
FROM raw_orders
UNION ALL SELECT 'raw_orders.order_approved_at',
       MIN(NULLIF(TRIM(order_approved_at), '')), MAX(NULLIF(TRIM(order_approved_at), '')),
       COUNT(NULLIF(TRIM(order_approved_at), ''))
FROM raw_orders
UNION ALL SELECT 'raw_orders.order_delivered_carrier_date',
       MIN(NULLIF(TRIM(order_delivered_carrier_date), '')), MAX(NULLIF(TRIM(order_delivered_carrier_date), '')),
       COUNT(NULLIF(TRIM(order_delivered_carrier_date), ''))
FROM raw_orders
UNION ALL SELECT 'raw_orders.order_delivered_customer_date',
       MIN(NULLIF(TRIM(order_delivered_customer_date), '')), MAX(NULLIF(TRIM(order_delivered_customer_date), '')),
       COUNT(NULLIF(TRIM(order_delivered_customer_date), ''))
FROM raw_orders
UNION ALL SELECT 'raw_orders.order_estimated_delivery_date',
       MIN(NULLIF(TRIM(order_estimated_delivery_date), '')), MAX(NULLIF(TRIM(order_estimated_delivery_date), '')),
       COUNT(NULLIF(TRIM(order_estimated_delivery_date), ''))
FROM raw_orders
UNION ALL SELECT 'raw_order_items.shipping_limit_date',
       MIN(NULLIF(TRIM(shipping_limit_date), '')), MAX(NULLIF(TRIM(shipping_limit_date), '')),
       COUNT(NULLIF(TRIM(shipping_limit_date), ''))
FROM raw_order_items
UNION ALL SELECT 'raw_order_reviews.review_creation_date',
       MIN(NULLIF(TRIM(review_creation_date), '')), MAX(NULLIF(TRIM(review_creation_date), '')),
       COUNT(NULLIF(TRIM(review_creation_date), ''))
FROM raw_order_reviews
UNION ALL SELECT 'raw_order_reviews.review_answer_timestamp',
       MIN(NULLIF(TRIM(review_answer_timestamp), '')), MAX(NULLIF(TRIM(review_answer_timestamp), '')),
       COUNT(NULLIF(TRIM(review_answer_timestamp), ''))
FROM raw_order_reviews
UNION ALL SELECT 'raw_marketing_qualified_leads.first_contact_date',
       MIN(NULLIF(TRIM(first_contact_date), '')), MAX(NULLIF(TRIM(first_contact_date), '')),
       COUNT(NULLIF(TRIM(first_contact_date), ''))
FROM raw_marketing_qualified_leads
UNION ALL SELECT 'raw_closed_deals.won_date',
       MIN(NULLIF(TRIM(won_date), '')), MAX(NULLIF(TRIM(won_date), '')),
       COUNT(NULLIF(TRIM(won_date), ''))
FROM raw_closed_deals
ORDER BY column_name;

-- ============================================================
-- 8. Numeric-field boundaries
-- Raw numbers are stored as text, and text sorts alphabetically
-- ('9.99' > '1000'). So each value is CAST to a number inside the query
-- before MIN / MAX / AVG - the raw column itself is not modified.
-- ============================================================
SELECT 'raw_order_items.price' AS column_name,
       COUNT(NULLIF(TRIM(price), '')) AS non_blank_count,
       MIN(CAST(NULLIF(TRIM(price), '') AS DECIMAL(15, 2))) AS min_value,
       MAX(CAST(NULLIF(TRIM(price), '') AS DECIMAL(15, 2))) AS max_value,
       ROUND(AVG(CAST(NULLIF(TRIM(price), '') AS DECIMAL(15, 2))), 2) AS avg_value
FROM raw_order_items
UNION ALL SELECT 'raw_order_items.freight_value',
       COUNT(NULLIF(TRIM(freight_value), '')),
       MIN(CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(15, 2))),
       MAX(CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(15, 2))),
       ROUND(AVG(CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(15, 2))), 2)
FROM raw_order_items
UNION ALL SELECT 'raw_order_payments.payment_value',
       COUNT(NULLIF(TRIM(payment_value), '')),
       MIN(CAST(NULLIF(TRIM(payment_value), '') AS DECIMAL(15, 2))),
       MAX(CAST(NULLIF(TRIM(payment_value), '') AS DECIMAL(15, 2))),
       ROUND(AVG(CAST(NULLIF(TRIM(payment_value), '') AS DECIMAL(15, 2))), 2)
FROM raw_order_payments
UNION ALL SELECT 'raw_order_payments.payment_installments',
       COUNT(NULLIF(TRIM(payment_installments), '')),
       MIN(CAST(NULLIF(TRIM(payment_installments), '') AS DECIMAL(15, 2))),
       MAX(CAST(NULLIF(TRIM(payment_installments), '') AS DECIMAL(15, 2))),
       ROUND(AVG(CAST(NULLIF(TRIM(payment_installments), '') AS DECIMAL(15, 2))), 2)
FROM raw_order_payments
UNION ALL SELECT 'raw_order_reviews.review_score',
       COUNT(NULLIF(TRIM(review_score), '')),
       MIN(CAST(NULLIF(TRIM(review_score), '') AS DECIMAL(15, 2))),
       MAX(CAST(NULLIF(TRIM(review_score), '') AS DECIMAL(15, 2))),
       ROUND(AVG(CAST(NULLIF(TRIM(review_score), '') AS DECIMAL(15, 2))), 2)
FROM raw_order_reviews
UNION ALL SELECT 'raw_products.product_weight_g',
       COUNT(NULLIF(TRIM(product_weight_g), '')),
       MIN(CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(15, 2))),
       MAX(CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(15, 2))),
       ROUND(AVG(CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(15, 2))), 2)
FROM raw_products
UNION ALL SELECT 'raw_products.product_photos_qty',
       COUNT(NULLIF(TRIM(product_photos_qty), '')),
       MIN(CAST(NULLIF(TRIM(product_photos_qty), '') AS DECIMAL(15, 2))),
       MAX(CAST(NULLIF(TRIM(product_photos_qty), '') AS DECIMAL(15, 2))),
       ROUND(AVG(CAST(NULLIF(TRIM(product_photos_qty), '') AS DECIMAL(15, 2))), 2)
FROM raw_products
ORDER BY column_name;

-- ============================================================
-- 9. Controlled raw samples
-- First 10 rows by key (ORDER BY makes the sample repeatable).
-- ============================================================
SELECT customer_id, customer_unique_id, customer_city, customer_state
FROM raw_customers
ORDER BY customer_id
LIMIT 10;

SELECT order_id, customer_id, order_status, order_purchase_timestamp
FROM raw_orders
ORDER BY order_id
LIMIT 10;

SELECT order_id, order_item_id, product_id, seller_id, price
FROM raw_order_items
ORDER BY order_id, order_item_id
LIMIT 10;

SELECT order_id, payment_sequential, payment_type, payment_value
FROM raw_order_payments
ORDER BY order_id, payment_sequential
LIMIT 10;

SELECT review_id, order_id, review_score, review_comment_message
FROM raw_order_reviews
ORDER BY review_id, order_id
LIMIT 10;

SELECT mql_id, first_contact_date, origin
FROM raw_marketing_qualified_leads
ORDER BY mql_id
LIMIT 10;

SELECT mql_id, seller_id, business_segment, business_type
FROM raw_closed_deals
ORDER BY mql_id
LIMIT 10;
