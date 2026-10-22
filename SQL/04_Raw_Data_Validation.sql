-- =============================================================================
-- Project : Customer Shopping Behavior Analysis
-- Script  : 04_Raw_Data_Validation.sql
-- Layer   : Raw Validation
-- Purpose : Validate loaded raw tables before staging and cleaning.
-- This script:
--   1. Identifies data-quality failures.
--   2. Identifies duplicate business keys.
--   3. Validates parent-child relationships.
--   4. Validates domains, formats, and business rules.
--   5. Reconciles source row counts with loaded raw tables.
--   6. Produces a final PASS/FAIL control result (a single overall_status row).
-- Important:
--   Raw values are stored as VARCHAR to preserve the source.
--   CAST(), STR_TO_DATE(), and REGEXP are used only as validation
--   expressions. They do not modify the raw data.
-- Status definitions:
--   PASS   = validation condition satisfied.
--   FAIL   = a load/structure defect (missing keys, broken parent-child links,
--            bad formats, row-count mismatch). FAIL blocks staging.
--   REVIEW = a genuine anomaly that exists in the SOURCE data itself (duplicate
--            review IDs, impossible date orders, 0 instalments). It is reported,
--            counted and handed to the cleaning step; it does not block staging.
--   INFO   = informational relationship or coverage finding (for example closed
--            deals with no seller record). A business finding, not an error.
-- Run this whole script in ONE session: it uses temporary tables, which are
-- private to the session and disappear when it ends.
-- =============================================================================
USE olist_acquisition_revenue_analytics;
-- =============================================================================
-- 01. REQUIRED BUSINESS-KEY COMPLETENESS
-- =============================================================================
-- Business question:
-- Are required identifiers populated?
--
-- NULL and empty-string values are evaluated separately from whitespace.
-- No TRIM or other cleaning operation is performed.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_required_key_checks AS 
SELECT 
  dataset, 
  column_name, 
  invalid_count, 
  CASE WHEN invalid_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status 
FROM 
  (
    SELECT 
      'customers' AS dataset, 
      'customer_id' AS column_name, 
      SUM(
        CASE WHEN customer_id IS NULL 
        OR customer_id = '' THEN 1 ELSE 0 END
      ) AS invalid_count 
    FROM 
      raw_customers 
    UNION ALL 
    SELECT 
      'sellers', 
      'seller_id', 
      SUM(
        CASE WHEN seller_id IS NULL 
        OR seller_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_sellers 
    UNION ALL 
    SELECT 
      'products', 
      'product_id', 
      SUM(
        CASE WHEN product_id IS NULL 
        OR product_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_products 
    UNION ALL 
    SELECT 
      'orders', 
      'order_id', 
      SUM(
        CASE WHEN order_id IS NULL 
        OR order_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_orders 
    UNION ALL 
    SELECT 
      'orders', 
      'customer_id', 
      SUM(
        CASE WHEN customer_id IS NULL 
        OR customer_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_orders 
    UNION ALL 
    SELECT 
      'order_items', 
      'order_id', 
      SUM(
        CASE WHEN order_id IS NULL 
        OR order_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_order_items 
    UNION ALL 
    SELECT 
      'order_items', 
      'product_id', 
      SUM(
        CASE WHEN product_id IS NULL 
        OR product_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_order_items 
    UNION ALL 
    SELECT 
      'order_items', 
      'seller_id', 
      SUM(
        CASE WHEN seller_id IS NULL 
        OR seller_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_order_items 
    UNION ALL 
    SELECT 
      'order_payments', 
      'order_id', 
      SUM(
        CASE WHEN order_id IS NULL 
        OR order_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_order_payments 
    UNION ALL 
    SELECT 
      'order_reviews', 
      'review_id', 
      SUM(
        CASE WHEN review_id IS NULL 
        OR review_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_order_reviews 
    UNION ALL 
    SELECT 
      'order_reviews', 
      'order_id', 
      SUM(
        CASE WHEN order_id IS NULL 
        OR order_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_order_reviews 
    UNION ALL 
    SELECT 
      'marketing_qualified_leads', 
      'mql_id', 
      SUM(
        CASE WHEN mql_id IS NULL 
        OR mql_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_marketing_qualified_leads 
    UNION ALL 
    SELECT 
      'closed_deals', 
      'mql_id', 
      SUM(
        CASE WHEN mql_id IS NULL 
        OR mql_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_closed_deals 
    UNION ALL 
    SELECT 
      'closed_deals', 
      'seller_id', 
      SUM(
        CASE WHEN seller_id IS NULL 
        OR seller_id = '' THEN 1 ELSE 0 END
      ) 
    FROM 
      raw_closed_deals
  ) AS key_checks;
SELECT 
    dataset, column_name, invalid_count, status
FROM
    tmp_required_key_checks
ORDER BY dataset , column_name;
-- =============================================================================
-- 02. DUPLICATE BUSINESS-KEY / GRAIN CHECKS
-- =============================================================================
-- Duplicate findings do not automatically fail raw validation.
--
-- The raw dataset can legitimately contain repeated business identifiers
-- because the table grain may be different from entity grain.
--
-- These findings are therefore classified as REVIEW.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_duplicate_checks AS 
SELECT 
  dataset, 
  column_name, 
  duplicate_count, 
  CASE WHEN duplicate_count = 0 THEN 'CLEAN' ELSE 'REVIEW' END AS status 
FROM 
  (
    SELECT 
      'customers' AS dataset, 
      'customer_id' AS column_name, 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) AS duplicate_count 
    FROM 
      (
        SELECT 
          customer_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_customers 
        WHERE 
          customer_id IS NOT NULL 
          AND customer_id <> '' 
        GROUP BY 
          customer_id 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'sellers', 
      'seller_id', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          seller_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_sellers 
        WHERE 
          seller_id IS NOT NULL 
          AND seller_id <> '' 
        GROUP BY 
          seller_id 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'products', 
      'product_id', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          product_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_products 
        WHERE 
          product_id IS NOT NULL 
          AND product_id <> '' 
        GROUP BY 
          product_id 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'orders', 
      'order_id', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          order_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_orders 
        WHERE 
          order_id IS NOT NULL 
          AND order_id <> '' 
        GROUP BY 
          order_id 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'order_reviews', 
      'review_id', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          review_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_order_reviews 
        WHERE 
          review_id IS NOT NULL 
          AND review_id <> '' 
        GROUP BY 
          review_id 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'order_items', 
      '(order_id, order_item_id)', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          order_id, 
          order_item_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_order_items 
        WHERE 
          order_id IS NOT NULL 
          AND order_id <> '' 
          AND order_item_id IS NOT NULL 
          AND order_item_id <> '' 
        GROUP BY 
          order_id, 
          order_item_id 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'order_payments', 
      '(order_id, payment_sequential)', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          order_id, 
          payment_sequential, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_order_payments 
        WHERE 
          order_id IS NOT NULL 
          AND order_id <> '' 
          AND payment_sequential IS NOT NULL 
          AND payment_sequential <> '' 
        GROUP BY 
          order_id, 
          payment_sequential 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'marketing_qualified_leads', 
      'mql_id', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          mql_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_marketing_qualified_leads 
        WHERE 
          mql_id IS NOT NULL 
          AND mql_id <> '' 
        GROUP BY 
          mql_id 
        HAVING 
          COUNT(*) > 1
      ) AS d 
    UNION ALL 
    SELECT 
      'closed_deals', 
      'mql_id', 
      COALESCE(
        SUM(duplicate_rows), 
        0
      ) 
    FROM 
      (
        SELECT 
          mql_id, 
          COUNT(*) -1 AS duplicate_rows 
        FROM 
          raw_closed_deals 
        WHERE 
          mql_id IS NOT NULL 
          AND mql_id <> '' 
        GROUP BY 
          mql_id 
        HAVING 
          COUNT(*) > 1
      ) AS d
  ) AS duplicate_checks;
SELECT 
    dataset, column_name, duplicate_count, status
FROM
    tmp_duplicate_checks
ORDER BY dataset , column_name;
-- =============================================================================
-- 03. REFERENTIAL INTEGRITY
-- =============================================================================
-- Business question:
-- Do child records reference existing parent records?
--
-- Integrity failures feed the overall PASS/FAIL decision.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_relationship_checks AS 
SELECT 
  relationship, 
  check_type, 
  unmatched_records, 
  CASE WHEN check_type = 'Integrity' 
  AND unmatched_records = 0 THEN 'PASS' WHEN check_type = 'Integrity' THEN 'FAIL' ELSE 'INFO' END AS status 
FROM 
  (
    SELECT 
      'orders -> customers' AS relationship, 
      'Integrity' AS check_type, 
      COUNT(*) AS unmatched_records 
    FROM 
      raw_orders AS o 
    WHERE 
      o.customer_id IS NOT NULL 
      AND o.customer_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_customers AS c 
        WHERE 
          c.customer_id = o.customer_id
      ) 
    UNION ALL 
    SELECT 
      'order_items -> orders', 
      'Integrity', 
      COUNT(*) 
    FROM 
      raw_order_items AS oi 
    WHERE 
      oi.order_id IS NOT NULL 
      AND oi.order_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_orders AS o 
        WHERE 
          o.order_id = oi.order_id
      ) 
    UNION ALL 
    SELECT 
      'order_items -> products', 
      'Integrity', 
      COUNT(*) 
    FROM 
      raw_order_items AS oi 
    WHERE 
      oi.product_id IS NOT NULL 
      AND oi.product_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_products AS p 
        WHERE 
          p.product_id = oi.product_id
      ) 
    UNION ALL 
    SELECT 
      'order_items -> sellers', 
      'Integrity', 
      COUNT(*) 
    FROM 
      raw_order_items AS oi 
    WHERE 
      oi.seller_id IS NOT NULL 
      AND oi.seller_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_sellers AS s 
        WHERE 
          s.seller_id = oi.seller_id
      ) 
    UNION ALL 
    SELECT 
      'order_payments -> orders', 
      'Integrity', 
      COUNT(*) 
    FROM 
      raw_order_payments AS op 
    WHERE 
      op.order_id IS NOT NULL 
      AND op.order_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_orders AS o 
        WHERE 
          o.order_id = op.order_id
      ) 
    UNION ALL 
    SELECT 
      'order_reviews -> orders', 
      'Integrity', 
      COUNT(*) 
    FROM 
      raw_order_reviews AS r 
    WHERE 
      r.order_id IS NOT NULL 
      AND r.order_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_orders AS o 
        WHERE 
          o.order_id = r.order_id
      ) 
    UNION ALL 
    SELECT 
      'closed_deals -> marketing_qualified_leads', 
      'Integrity', 
      COUNT(*) 
    FROM 
      raw_closed_deals AS cd 
    WHERE 
      cd.mql_id IS NOT NULL 
      AND cd.mql_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_marketing_qualified_leads AS ml 
        WHERE 
          ml.mql_id = cd.mql_id
      ) 
    UNION ALL 
    SELECT 
      'products -> category_translation', 
      'Informational', 
      COUNT(*) 
    FROM 
      raw_products AS p 
    WHERE 
      p.product_category_name IS NOT NULL 
      AND p.product_category_name <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_product_category_translation AS pct 
        WHERE 
          pct.product_category_name = p.product_category_name
      ) 
    UNION ALL 
    SELECT 
      'closed_deals -> sellers', 
      'Informational', 
      COUNT(*) 
    FROM 
      raw_closed_deals AS cd 
    WHERE 
      cd.seller_id IS NOT NULL 
      AND cd.seller_id <> '' 
      AND NOT EXISTS (
        SELECT 
          1 
        FROM 
          raw_sellers AS s 
        WHERE 
          s.seller_id = cd.seller_id
      )
  ) AS relationship_checks;
SELECT 
    relationship, check_type, unmatched_records, status
FROM
    tmp_relationship_checks
ORDER BY check_type , relationship;
-- =============================================================================
-- 04. DOMAIN VALIDATION
-- =============================================================================
-- Business question:
-- Do controlled categorical fields contain expected source values?
-- =============================================================================
CREATE TEMPORARY TABLE tmp_domain_checks AS 
SELECT 
  'orders' AS dataset, 
  'order_status' AS column_name, 
  COUNT(*) AS invalid_records 
FROM 
  raw_orders 
WHERE 
  order_status IS NOT NULL 
  AND order_status <> '' 
  AND order_status NOT IN (
    'delivered', 'shipped', 'canceled', 
    'unavailable', 'invoiced', 'processing', 
    'created', 'approved'
  ) 
UNION ALL 
SELECT 
  'order_payments', 
  'payment_type', 
  COUNT(*) 
FROM 
  raw_order_payments 
WHERE 
  payment_type IS NOT NULL 
  AND payment_type <> '' 
  AND payment_type NOT IN (
    'credit_card', 'boleto', 'voucher', 
    'debit_card', 'not_defined'
  ) 
UNION ALL 
SELECT 
  'order_reviews', 
  'review_score', 
  COUNT(*) 
FROM 
  raw_order_reviews 
WHERE 
  review_score IS NOT NULL 
  AND review_score <> '' 
  AND (
    review_score NOT REGEXP '^[0-9]+$' 
    OR CAST(review_score AS UNSIGNED) NOT BETWEEN 1 
    AND 5
  );
SELECT 
    dataset,
    column_name,
    invalid_records,
    CASE
        WHEN invalid_records = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM
    tmp_domain_checks
ORDER BY dataset , column_name;
-- =============================================================================
-- 05. NUMERIC FORMAT AND RANGE VALIDATION
-- =============================================================================
-- Business question:
-- Can raw numeric fields be safely interpreted during staging?
-- =============================================================================
CREATE TEMPORARY TABLE tmp_numeric_checks AS 
SELECT 
  'order_items' AS dataset, 
  'price' AS column_name, 
  COUNT(*) AS invalid_records 
FROM 
  raw_order_items 
WHERE 
  price IS NOT NULL 
  AND price <> '' 
  AND (
    price NOT REGEXP '^[0-9]+([.][0-9]+)?$' 
    OR CAST(
      price AS DECIMAL(15, 2)
    ) < 0
  ) 
UNION ALL 
SELECT 
  'order_items', 
  'freight_value', 
  COUNT(*) 
FROM 
  raw_order_items 
WHERE 
  freight_value IS NOT NULL 
  AND freight_value <> '' 
  AND (
    freight_value NOT REGEXP '^[0-9]+([.][0-9]+)?$' 
    OR CAST(
      freight_value AS DECIMAL(15, 2)
    ) < 0
  ) 
UNION ALL 
SELECT 
  'order_payments', 
  'payment_value', 
  COUNT(*) 
FROM 
  raw_order_payments 
WHERE 
  payment_value IS NOT NULL 
  AND payment_value <> '' 
  AND (
    payment_value NOT REGEXP '^[0-9]+([.][0-9]+)?$' 
    OR CAST(
      payment_value AS DECIMAL(15, 2)
    ) < 0
  ) 
UNION ALL 
SELECT 
  'order_payments', 
  'payment_sequential', 
  COUNT(*) 
FROM 
  raw_order_payments 
WHERE 
  payment_sequential IS NOT NULL 
  AND payment_sequential <> '' 
  AND payment_sequential NOT REGEXP '^[0-9]+$' 
UNION ALL 
SELECT 
  'order_payments', 
  'payment_installments', 
  COUNT(*) 
FROM 
  raw_order_payments 
WHERE 
  payment_installments IS NOT NULL 
  AND payment_installments <> '' 
  AND (
    payment_installments NOT REGEXP '^[0-9]+$' 
    OR CAST(payment_installments AS UNSIGNED) < 1
  ) 
UNION ALL 
SELECT 
  'products', 
  'product_weight_g', 
  COUNT(*) 
FROM 
  raw_products 
WHERE 
  product_weight_g IS NOT NULL 
  AND product_weight_g <> '' 
  AND (
    product_weight_g NOT REGEXP '^[0-9]+([.][0-9]+)?$' 
    OR CAST(
      product_weight_g AS DECIMAL(15, 2)
    ) < 0
  ) 
UNION ALL 
SELECT 
  'products', 
  'product_length_cm', 
  COUNT(*) 
FROM 
  raw_products 
WHERE 
  product_length_cm IS NOT NULL 
  AND product_length_cm <> '' 
  AND (
    product_length_cm NOT REGEXP '^[0-9]+([.][0-9]+)?$' 
    OR CAST(
      product_length_cm AS DECIMAL(15, 2)
    ) < 0
  ) 
UNION ALL 
SELECT 
  'products', 
  'product_height_cm', 
  COUNT(*) 
FROM 
  raw_products 
WHERE 
  product_height_cm IS NOT NULL 
  AND product_height_cm <> '' 
  AND (
    product_height_cm NOT REGEXP '^[0-9]+([.][0-9]+)?$' 
    OR CAST(
      product_height_cm AS DECIMAL(15, 2)
    ) < 0
  ) 
UNION ALL 
SELECT 
  'products', 
  'product_width_cm', 
  COUNT(*) 
FROM 
  raw_products 
WHERE 
  product_width_cm IS NOT NULL 
  AND product_width_cm <> '' 
  AND (
    product_width_cm NOT REGEXP '^[0-9]+([.][0-9]+)?$' 
    OR CAST(
      product_width_cm AS DECIMAL(15, 2)
    ) < 0
  ) 
UNION ALL 
SELECT 
  'products', 
  'product_photos_qty', 
  COUNT(*) 
FROM 
  raw_products 
WHERE 
  product_photos_qty IS NOT NULL 
  AND product_photos_qty <> '' 
  AND (
    product_photos_qty NOT REGEXP '^[0-9]+$' 
    OR CAST(product_photos_qty AS UNSIGNED) < 0
  ) 
UNION ALL 
SELECT 
  'order_items', 
  'order_item_id', 
  COUNT(*) 
FROM 
  raw_order_items 
WHERE 
  order_item_id IS NOT NULL 
  AND order_item_id <> '' 
  AND order_item_id NOT REGEXP '^[0-9]+$';
-- payment_installments counts values below 1 as well as non-numeric text.
-- Olist contains a few orders with 0 instalments: a source anomaly -> REVIEW.
SELECT 
    dataset,
    column_name,
    invalid_records,
    CASE
        WHEN invalid_records = 0 THEN 'PASS'
        WHEN dataset = 'order_payments' AND column_name = 'payment_installments' THEN 'REVIEW'
        ELSE 'FAIL'
    END AS status
FROM
    tmp_numeric_checks
ORDER BY dataset , column_name;
-- =============================================================================
-- 06. DATE FORMAT VALIDATION
-- =============================================================================
-- Business question:
-- Can raw date/timestamp values be interpreted using the expected source
-- format?
--
-- STR_TO_DATE is used only for validation.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_date_checks AS 
SELECT 
  'orders' AS dataset, 
  'order_purchase_timestamp' AS column_name, 
  COUNT(*) AS invalid_records 
FROM 
  raw_orders 
WHERE 
  order_purchase_timestamp IS NOT NULL 
  AND order_purchase_timestamp <> '' 
  AND STR_TO_DATE(
    order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'
  ) IS NULL 
UNION ALL 
SELECT 
  'orders', 
  'order_approved_at', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_approved_at IS NOT NULL 
  AND order_approved_at <> '' 
  AND STR_TO_DATE(
    order_approved_at, '%Y-%m-%d %H:%i:%s'
  ) IS NULL 
UNION ALL 
SELECT 
  'orders', 
  'order_delivered_carrier_date', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_delivered_carrier_date IS NOT NULL 
  AND order_delivered_carrier_date <> '' 
  AND STR_TO_DATE(
    order_delivered_carrier_date, '%Y-%m-%d %H:%i:%s'
  ) IS NULL 
UNION ALL 
SELECT 
  'orders', 
  'order_delivered_customer_date', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_delivered_customer_date IS NOT NULL 
  AND order_delivered_customer_date <> '' 
  AND STR_TO_DATE(
    order_delivered_customer_date, '%Y-%m-%d %H:%i:%s'
  ) IS NULL 
UNION ALL 
SELECT 
  'orders', 
  'order_estimated_delivery_date', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_estimated_delivery_date IS NOT NULL 
  AND order_estimated_delivery_date <> '' 
  AND STR_TO_DATE(
    order_estimated_delivery_date, '%Y-%m-%d %H:%i:%s'
  ) IS NULL 
UNION ALL 
SELECT 
  'marketing_qualified_leads', 
  'first_contact_date', 
  COUNT(*) 
FROM 
  raw_marketing_qualified_leads 
WHERE 
  first_contact_date IS NOT NULL 
  AND first_contact_date <> '' 
  AND STR_TO_DATE(first_contact_date, '%Y-%m-%d') IS NULL 
UNION ALL 
SELECT 
  'closed_deals', 
  'won_date', 
  COUNT(*) 
FROM 
  raw_closed_deals 
WHERE 
  won_date IS NOT NULL 
  AND won_date <> '' 
  AND STR_TO_DATE(won_date, '%Y-%m-%d %H:%i:%s') IS NULL 
UNION ALL 
SELECT 
  'order_items', 
  'shipping_limit_date', 
  COUNT(*) 
FROM 
  raw_order_items 
WHERE 
  shipping_limit_date IS NOT NULL 
  AND shipping_limit_date <> '' 
  AND STR_TO_DATE(shipping_limit_date, '%Y-%m-%d %H:%i:%s') IS NULL 
UNION ALL 
SELECT 
  'order_reviews', 
  'review_creation_date', 
  COUNT(*) 
FROM 
  raw_order_reviews 
WHERE 
  review_creation_date IS NOT NULL 
  AND review_creation_date <> '' 
  AND STR_TO_DATE(review_creation_date, '%Y-%m-%d %H:%i:%s') IS NULL 
UNION ALL 
-- review_answer_timestamp drives the "keep latest review" cleaning rule,
-- so it must be a valid timestamp before staging.
SELECT 
  'order_reviews', 
  'review_answer_timestamp', 
  COUNT(*) 
FROM 
  raw_order_reviews 
WHERE 
  review_answer_timestamp IS NOT NULL 
  AND review_answer_timestamp <> '' 
  AND STR_TO_DATE(review_answer_timestamp, '%Y-%m-%d %H:%i:%s') IS NULL;
SELECT 
    dataset,
    column_name,
    invalid_records,
    CASE
        WHEN invalid_records = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM
    tmp_date_checks
ORDER BY dataset , column_name;
-- =============================================================================
-- 07. CROSS-FIELD CONSISTENCY
-- =============================================================================
-- Business question:
-- Do related fields follow logical business rules?
--
-- Violations here are anomalies recorded in the source system itself (for
-- example an order with a delivery date but a non-delivered status). They are
-- reported as REVIEW so the cleaning step can decide how to treat them; they
-- are not load failures and do not block staging.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_consistency_checks AS 
SELECT 
  'delivered orders without customer delivery date' AS check_name, 
  COUNT(*) AS invalid_records 
FROM 
  raw_orders 
WHERE 
  order_status = 'delivered' 
  AND (
    order_delivered_customer_date IS NULL 
    OR order_delivered_customer_date = ''
  ) 
UNION ALL 
SELECT 
  'non-delivered orders with customer delivery date', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_status <> 'delivered' 
  AND order_delivered_customer_date IS NOT NULL 
  AND order_delivered_customer_date <> '' 
UNION ALL 
SELECT 
  'approved before purchase', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_purchase_timestamp IS NOT NULL 
  AND order_purchase_timestamp <> '' 
  AND order_approved_at IS NOT NULL 
  AND order_approved_at <> '' 
  AND STR_TO_DATE(
    order_approved_at, '%Y-%m-%d %H:%i:%s'
  ) < STR_TO_DATE(
    order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'
  ) 
UNION ALL 
SELECT 
  'carrier delivery before purchase', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_purchase_timestamp IS NOT NULL 
  AND order_purchase_timestamp <> '' 
  AND order_delivered_carrier_date IS NOT NULL 
  AND order_delivered_carrier_date <> '' 
  AND STR_TO_DATE(
    order_delivered_carrier_date, '%Y-%m-%d %H:%i:%s'
  ) < STR_TO_DATE(
    order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'
  ) 
UNION ALL 
SELECT 
  'customer delivery before purchase', 
  COUNT(*) 
FROM 
  raw_orders 
WHERE 
  order_purchase_timestamp IS NOT NULL 
  AND order_purchase_timestamp <> '' 
  AND order_delivered_customer_date IS NOT NULL 
  AND order_delivered_customer_date <> '' 
  AND STR_TO_DATE(
    order_delivered_customer_date, '%Y-%m-%d %H:%i:%s'
  ) < STR_TO_DATE(
    order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'
  );
SELECT 
    check_name,
    invalid_records,
    CASE
        WHEN invalid_records = 0 THEN 'PASS'
        ELSE 'REVIEW'
    END AS status
FROM
    tmp_consistency_checks
ORDER BY check_name;
-- =============================================================================
-- 08. MARKETING FUNNEL COVERAGE
-- =============================================================================
-- Business question:
-- How many qualified leads progressed to closed deals?
--
-- This is informational, not a data-quality failure.
-- DISTINCT is intentionally applied to the closed-deal side because the
-- business analysis is at MQL level, not closed-deal-row level.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_funnel_checks AS 
SELECT 
  qualified_leads, 
  converted_leads, 
  non_converted_leads, 
  CASE WHEN qualified_leads = converted_leads + non_converted_leads THEN 'PASS' ELSE 'FAIL' END AS status 
FROM 
  (
    SELECT 
      COUNT(*) AS qualified_leads, 
      SUM(
        CASE WHEN cd.mql_id IS NOT NULL THEN 1 ELSE 0 END
      ) AS converted_leads, 
      SUM(
        CASE WHEN cd.mql_id IS NULL THEN 1 ELSE 0 END
      ) AS non_converted_leads 
    FROM 
      raw_marketing_qualified_leads AS ml 
      LEFT JOIN (
        SELECT 
          DISTINCT mql_id 
        FROM 
          raw_closed_deals 
        WHERE 
          mql_id IS NOT NULL 
          AND mql_id <> ''
      ) AS cd ON ml.mql_id = cd.mql_id
  ) AS funnel;
SELECT 
    qualified_leads,
    converted_leads,
    non_converted_leads,
    status
FROM
    tmp_funnel_checks;
-- =============================================================================
-- 09. SOURCE-TO-RAW ROW-COUNT RECONCILIATION
-- =============================================================================
-- Business question:
-- Does every loaded raw table contain exactly the number of records that
-- Notebook 01 counted in the source CSV file?
--
-- Expected counts come from the control table meta_expected_row_counts
-- (loaded from Reference_Data/raw_data_ingestion_summary.csv).
-- No expected value is hard-coded in this script.
--
-- The query starts from the ACTUAL raw tables and LEFT JOINs the control
-- table. A raw table with no control record is therefore a FAIL, rather than
-- silently disappearing from the check (which an INNER JOIN would allow, and
-- which would let an empty control table pass the whole gate).
-- Both the file-level count measured by the notebook (`rows`) and the notebook's
-- configured baseline (`expected_rows`) must equal the loaded row count.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_row_count_checks AS
SELECT a.table_name,
       e.source_file,
       e.`rows`          AS source_file_rows,
       e.expected_rows,
       a.actual_rows,
       CASE
           WHEN e.table_name IS NULL              THEN 'FAIL'  -- no control record
           WHEN a.actual_rows = e.`rows`
            AND a.actual_rows = e.expected_rows   THEN 'PASS'
           ELSE 'FAIL'
       END AS status
FROM (
    SELECT 'raw_customers' AS table_name, COUNT(*) AS actual_rows FROM raw_customers
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
) AS a
LEFT JOIN meta_expected_row_counts AS e
       ON e.table_name = a.table_name;

SELECT table_name, source_file, source_file_rows, expected_rows, actual_rows, status
FROM tmp_row_count_checks
ORDER BY table_name;

-- Control-table health: exactly one record per table, and every source file
-- passed Notebook 01's own validation. (Counted as failures in the rollup.)
SELECT COUNT(*)                         AS control_rows,
       COUNT(DISTINCT table_name)       AS distinct_tables,
       SUM(status <> 'PASS')            AS control_rows_not_pass
FROM meta_expected_row_counts;

-- =============================================================================
-- 10. ORDER REVIEW CONTENT INTEGRITY
-- =============================================================================
-- Business question:
-- Does the reviews table contain valid required identifiers and review scores?
-- =============================================================================
CREATE TEMPORARY TABLE tmp_content_integrity_checks AS
SELECT reviews_with_blank_id,
       reviews_with_blank_order_id,
       reviews_with_invalid_score,
       CASE WHEN reviews_with_blank_id = 0
             AND reviews_with_blank_order_id = 0
             AND reviews_with_invalid_score = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT SUM(CASE WHEN review_id IS NULL OR review_id = '' THEN 1 ELSE 0 END)       AS reviews_with_blank_id,
           SUM(CASE WHEN order_id  IS NULL OR order_id  = '' THEN 1 ELSE 0 END)       AS reviews_with_blank_order_id,
           SUM(CASE WHEN review_score IS NOT NULL AND review_score <> ''
                     AND (review_score NOT REGEXP '^[0-9]+$'
                          OR CAST(review_score AS UNSIGNED) NOT BETWEEN 1 AND 5)
                    THEN 1 ELSE 0 END)                                                 AS reviews_with_invalid_score
    FROM raw_order_reviews
) AS content_checks;

SELECT reviews_with_blank_id, reviews_with_blank_order_id, reviews_with_invalid_score, status
FROM tmp_content_integrity_checks;

-- =============================================================================
-- 11. GEOGRAPHIC VALIDATION
-- =============================================================================
-- Business question:
-- Are latitude and longitude values numeric and within valid ranges?
-- =============================================================================
CREATE TEMPORARY TABLE tmp_geo_checks AS
SELECT 'geolocation_latitude' AS validation_check,
       COUNT(*)              AS invalid_records
FROM raw_geolocation
WHERE geolocation_lat IS NOT NULL AND geolocation_lat <> ''
  AND (geolocation_lat NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
       OR CAST(geolocation_lat AS DECIMAL(12, 8)) NOT BETWEEN -90 AND 90)
UNION ALL
SELECT 'geolocation_longitude',
       COUNT(*)
FROM raw_geolocation
WHERE geolocation_lng IS NOT NULL AND geolocation_lng <> ''
  AND (geolocation_lng NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
       OR CAST(geolocation_lng AS DECIMAL(12, 8)) NOT BETWEEN -180 AND 180);

SELECT validation_check,
       invalid_records,
       CASE WHEN invalid_records = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM tmp_geo_checks;

-- =============================================================================
-- 12. OVERALL VALIDATION ROLLUP
-- =============================================================================
-- Every finding is collected into ONE table, tmp_validation_rollup.
-- (Each INSERT reads each temporary table once. MySQL does not allow a
--  temporary table to be referenced twice inside a single query - ERROR 1137 -
--  so the rollup is built statement by statement.)
--
--   severity CRITICAL : load/structure checks. finding_count = number of
--                       failed checks. Any value above 0 fails the gate.
--   severity REVIEW   : source-data anomalies. finding_count = affected records.
--   severity INFO     : coverage / relationship findings. finding_count =
--                       affected records.
-- =============================================================================
CREATE TEMPORARY TABLE tmp_validation_rollup (
    severity      VARCHAR(10)  NOT NULL,
    finding       VARCHAR(100) NOT NULL,
    measure       VARCHAR(20)  NOT NULL,
    finding_count BIGINT       NOT NULL
);

-- ---- CRITICAL: any failed check blocks staging ------------------------------
INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'required business keys', 'failed checks', COUNT(*)
FROM tmp_required_key_checks WHERE status = 'FAIL';

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'referential integrity', 'failed checks', COUNT(*)
FROM tmp_relationship_checks WHERE status = 'FAIL';

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'categorical domains', 'failed checks', COUNT(*)
FROM tmp_domain_checks WHERE invalid_records > 0;

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'numeric format and range', 'failed checks', COUNT(*)
FROM tmp_numeric_checks
WHERE invalid_records > 0
  AND NOT (dataset = 'order_payments' AND column_name = 'payment_installments');

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'date and timestamp format', 'failed checks', COUNT(*)
FROM tmp_date_checks WHERE invalid_records > 0;

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'geographic ranges', 'failed checks', COUNT(*)
FROM tmp_geo_checks WHERE invalid_records > 0;

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'source-to-raw row counts', 'failed checks', COUNT(*)
FROM tmp_row_count_checks WHERE status = 'FAIL';

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'review content integrity', 'failed checks', COUNT(*)
FROM tmp_content_integrity_checks WHERE status = 'FAIL';

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'funnel arithmetic', 'failed checks', COUNT(*)
FROM tmp_funnel_checks WHERE status = 'FAIL';

INSERT INTO tmp_validation_rollup
SELECT 'CRITICAL', 'control table integrity', 'failed checks',
       (COUNT(*) - COUNT(DISTINCT table_name)) + COALESCE(SUM(status <> 'PASS'), 0)
FROM meta_expected_row_counts;

-- ---- REVIEW: source anomalies, one row per finding --------------------------
INSERT INTO tmp_validation_rollup
SELECT 'REVIEW', CONCAT('duplicate ', dataset, '.', column_name), 'extra rows', duplicate_count
FROM tmp_duplicate_checks WHERE duplicate_count > 0;

INSERT INTO tmp_validation_rollup
SELECT 'REVIEW', check_name, 'records', invalid_records
FROM tmp_consistency_checks WHERE invalid_records > 0;

INSERT INTO tmp_validation_rollup
SELECT 'REVIEW', 'order_payments.payment_installments below 1', 'records', invalid_records
FROM tmp_numeric_checks
WHERE dataset = 'order_payments' AND column_name = 'payment_installments' AND invalid_records > 0;

-- ---- INFO: relationship / coverage findings ---------------------------------
INSERT INTO tmp_validation_rollup
SELECT 'INFO', CONCAT('no match: ', relationship), 'records', unmatched_records
FROM tmp_relationship_checks WHERE status = 'INFO' AND unmatched_records > 0;

INSERT INTO tmp_validation_rollup
SELECT 'INFO', 'leads not converted to a closed deal', 'records', non_converted_leads
FROM tmp_funnel_checks;

-- ---- 12a. Itemised findings --------------------------------------------------
SELECT severity,
       finding,
       measure,
       finding_count,
       CASE
           WHEN severity = 'CRITICAL' AND finding_count > 0 THEN 'FAIL'
           WHEN severity = 'CRITICAL'                       THEN 'PASS'
           ELSE severity
       END AS status
FROM tmp_validation_rollup
ORDER BY FIELD(severity, 'CRITICAL', 'REVIEW', 'INFO'), finding;

-- ---- 12b. Overall result -----------------------------------------------------
SELECT CASE WHEN SUM(severity = 'CRITICAL' AND finding_count > 0) = 0
            THEN 'PASS' ELSE 'FAIL' END                     AS overall_status,
       SUM(severity = 'CRITICAL')                           AS critical_checks_run,
       SUM(severity = 'CRITICAL' AND finding_count > 0)     AS critical_checks_failed,
       SUM(severity = 'REVIEW'   AND finding_count > 0)     AS review_findings,
       SUM(severity = 'INFO'     AND finding_count > 0)     AS info_findings
FROM tmp_validation_rollup;

-- =============================================================================
-- 13. RAW DATA VALIDATION GATE
-- =============================================================================
-- Staging (script 05 onwards) should proceed only when overall_status above
-- is PASS.
--
-- REVIEW findings : need a documented treatment in the cleaning step, but do
--                   not block the raw load.
-- INFO findings   : give business / coverage context and do not block anything.
-- =============================================================================

-- =============================================================================
-- 14. CLEAN UP SESSION-SCOPED VALIDATION TABLES
-- =============================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_required_key_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_duplicate_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_relationship_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_domain_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_numeric_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_date_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_consistency_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_funnel_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_row_count_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_content_integrity_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_geo_checks;
DROP TEMPORARY TABLE IF EXISTS tmp_validation_rollup;