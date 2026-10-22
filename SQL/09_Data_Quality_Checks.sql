-- =============================================================================
-- Script: 09_Data_Quality_Checks.sql
-- Layer : Data quality / reconciliation
-- Purpose: Emit evidence for schema, row counts, required keys, duplicates,
--          referential integrity and marketing-to-seller reconciliation.
-- Run after raw load, 04_Raw_Data_Validation.sql, and 06_Load_Staging.sql.
-- =============================================================================
USE olist_acquisition_revenue_analytics;

-- 1) Source-file schema and parser checks captured by the Python ingestion notebook.
SELECT source_file, `rows` AS source_rows, expected_rows, row_count_match,
       `columns` AS source_columns, expected_columns, schema_match, csv_readable, status
FROM meta_expected_row_counts
ORDER BY source_file;

-- 2) Source row counts vs raw database counts.
SELECT 'customers' AS dataset, 99441 AS expected_source_rows, COUNT(*) AS raw_rows,
       IF(COUNT(*) = 99441, 'PASS', 'CHECK') AS status FROM raw_customers
UNION ALL SELECT 'sellers', 3095, COUNT(*), IF(COUNT(*) = 3095, 'PASS', 'CHECK') FROM raw_sellers
UNION ALL SELECT 'product_category_translation', 71, COUNT(*), IF(COUNT(*) = 71, 'PASS', 'CHECK') FROM raw_product_category_translation
UNION ALL SELECT 'products', 32951, COUNT(*), IF(COUNT(*) = 32951, 'PASS', 'CHECK') FROM raw_products
UNION ALL SELECT 'orders', 99441, COUNT(*), IF(COUNT(*) = 99441, 'PASS', 'CHECK') FROM raw_orders
UNION ALL SELECT 'order_items', 112650, COUNT(*), IF(COUNT(*) = 112650, 'PASS', 'CHECK') FROM raw_order_items
UNION ALL SELECT 'order_payments', 103886, COUNT(*), IF(COUNT(*) = 103886, 'PASS', 'CHECK') FROM raw_order_payments
UNION ALL SELECT 'order_reviews', 99224, COUNT(*), IF(COUNT(*) = 99224, 'PASS', 'CHECK') FROM raw_order_reviews
UNION ALL SELECT 'geolocation', 1000163, COUNT(*), IF(COUNT(*) = 1000163, 'PASS', 'CHECK') FROM raw_geolocation
UNION ALL SELECT 'marketing_qualified_leads', 8000, COUNT(*), IF(COUNT(*) = 8000, 'PASS', 'CHECK') FROM raw_marketing_qualified_leads
UNION ALL SELECT 'closed_deals', 842, COUNT(*), IF(COUNT(*) = 842, 'PASS', 'CHECK') FROM raw_closed_deals;

-- 3) Required key NULL / blank checks. Each output row is a control.
SELECT 'raw_customers.customer_id' AS check_name,
       SUM(customer_id IS NULL OR TRIM(customer_id) = '') AS invalid_rows
FROM raw_customers
UNION ALL SELECT 'raw_sellers.seller_id',
       SUM(seller_id IS NULL OR TRIM(seller_id) = '') FROM raw_sellers
UNION ALL SELECT 'raw_orders.order_id',
       SUM(order_id IS NULL OR TRIM(order_id) = '') FROM raw_orders
UNION ALL SELECT 'raw_order_items.order_id',
       SUM(order_id IS NULL OR TRIM(order_id) = '') FROM raw_order_items
UNION ALL SELECT 'raw_order_reviews.review_id',
       SUM(review_id IS NULL OR TRIM(review_id) = '') FROM raw_order_reviews
UNION ALL SELECT 'raw_marketing_qualified_leads.mql_id',
       SUM(mql_id IS NULL OR TRIM(mql_id) = '') FROM raw_marketing_qualified_leads
UNION ALL SELECT 'raw_closed_deals.mql_id',
       SUM(mql_id IS NULL OR TRIM(mql_id) = '') FROM raw_closed_deals;

-- 4) Duplicate review IDs. Olist can contain repeated review IDs across rows;
-- report the number of extra rows beyond the first occurrence for each ID.
SELECT COUNT(*) AS duplicate_review_id_groups,
       COALESCE(SUM(row_count - 1), 0) AS duplicate_review_rows
FROM (
    SELECT review_id, COUNT(*) AS row_count
    FROM raw_order_reviews
    WHERE review_id IS NOT NULL AND TRIM(review_id) <> ''
    GROUP BY review_id
    HAVING COUNT(*) > 1
) d;

-- 5) Referential-integrity checks for common joins.
SELECT 'order_items -> orders' AS relationship,
       COUNT(*) AS orphan_rows
FROM stg_order_items i
LEFT JOIN stg_orders o ON o.order_id = i.order_id
WHERE o.order_id IS NULL
UNION ALL SELECT 'order_items -> products', COUNT(*)
FROM stg_order_items i
LEFT JOIN stg_products p ON p.product_id = i.product_id
WHERE p.product_id IS NULL
UNION ALL SELECT 'order_items -> sellers', COUNT(*)
FROM stg_order_items i
LEFT JOIN stg_sellers s ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL
UNION ALL SELECT 'orders -> customers', COUNT(*)
FROM stg_orders o
LEFT JOIN stg_customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL SELECT 'closed_deals -> seller master', COUNT(*)
FROM stg_closed_deals d
LEFT JOIN stg_sellers s ON s.seller_id = d.seller_id
WHERE s.seller_id IS NULL
UNION ALL SELECT 'closed_deals -> transactional seller IDs', COUNT(*)
FROM stg_closed_deals d
LEFT JOIN (SELECT DISTINCT seller_id FROM stg_order_items) t
  ON t.seller_id = d.seller_id
WHERE t.seller_id IS NULL;

-- 6) Marketing closed-deal reconciliation.
SELECT
    COUNT(*) AS closed_deals,
    SUM(s.seller_id IS NULL) AS deals_without_matching_transactional_seller,
    ROUND(100.0 * SUM(s.seller_id IS NULL) / NULLIF(COUNT(*), 0), 2) AS unmatched_pct,
    SUM(s.seller_id IS NOT NULL) AS deals_with_matching_seller
FROM stg_closed_deals d
LEFT JOIN (SELECT DISTINCT seller_id FROM stg_order_items) s
  ON s.seller_id = d.seller_id;

-- 7) Review-load row count. Expected source count: 99,224.
-- If count differs, inspect warnings from the immediately preceding LOAD DATA
-- statement and re-run the review load with ESCAPED BY '' and matching line ending.
SELECT COUNT(*) AS loaded_review_rows,
       IF(COUNT(*) = 99224, 'PASS', 'INVESTIGATE') AS review_load_status
FROM raw_order_reviews;

-- 8) Final quick table inventory for raw, staging and analytical layers.
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND (LEFT(table_name, 4) = 'raw_' OR LEFT(table_name, 4) = 'stg_' OR LEFT(table_name, 5) = 'mart_')
ORDER BY table_name;
