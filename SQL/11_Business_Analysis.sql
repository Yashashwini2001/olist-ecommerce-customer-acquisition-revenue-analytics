-- =============================================================================
-- 11_Business_Analysis.sql
-- Purpose: Clear, reusable queries for portfolio analysis and interview discussion.
-- Requires the raw and staging layers to have been loaded.
-- =============================================================================
USE olist_acquisition_revenue_analytics;

-- 1. Monthly marketplace trend. Item GMV excludes freight and is not profit.
SELECT DATE_FORMAT(STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'), '%Y-%m') AS purchase_month,
       COUNT(DISTINCT o.order_id) AS orders,
       COUNT(DISTINCT o.customer_id) AS customers,
       ROUND(SUM(CAST(NULLIF(oi.price, '') AS DECIMAL(12,2))), 2) AS item_gmv,
       ROUND(SUM(CAST(NULLIF(oi.freight_value, '') AS DECIMAL(12,2))), 2) AS freight_value
FROM stg_orders o
JOIN stg_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s') IS NOT NULL
GROUP BY purchase_month
ORDER BY purchase_month;

-- 2. Marketing funnel: leads and closed deals.
SELECT COUNT(DISTINCT m.mql_id) AS marketing_qualified_leads,
       COUNT(DISTINCT d.mql_id) AS closed_deals,
       ROUND(100.0 * COUNT(DISTINCT d.mql_id) / NULLIF(COUNT(DISTINCT m.mql_id), 0), 2) AS lead_to_deal_pct
FROM stg_marketing_qualified_leads m
LEFT JOIN stg_closed_deals d ON d.mql_id = m.mql_id;

-- 3. Closed deals matched to the seller master and to any transactional seller.
-- A missing transaction match is a reconciliation gap, not proof of bad attribution.
SELECT CASE WHEN s.seller_id IS NULL THEN 'NO_SELLER_MASTER_MATCH' ELSE 'SELLER_MASTER_MATCH' END AS seller_master_status,
       CASE WHEN tx.seller_id IS NULL THEN 'NO_TRANSACTION_MATCH' ELSE 'TRANSACTION_MATCH' END AS transaction_status,
       COUNT(*) AS closed_deals
FROM stg_closed_deals d
LEFT JOIN stg_sellers s ON s.seller_id = d.seller_id
LEFT JOIN (SELECT DISTINCT seller_id FROM stg_order_items WHERE seller_id IS NOT NULL AND TRIM(seller_id) <> '') tx
  ON tx.seller_id = d.seller_id
GROUP BY seller_master_status, transaction_status
ORDER BY closed_deals DESC;

-- 4. Delivery performance by order status.
SELECT order_status, COUNT(*) AS orders
FROM stg_orders
GROUP BY order_status
ORDER BY orders DESC;

-- 5. Review-score distribution.
SELECT CAST(NULLIF(review_score, '') AS UNSIGNED) AS review_score,
       COUNT(*) AS review_rows
FROM stg_order_reviews
WHERE NULLIF(review_score, '') REGEXP '^[1-5]$'
GROUP BY CAST(NULLIF(review_score, '') AS UNSIGNED)
ORDER BY review_score;

