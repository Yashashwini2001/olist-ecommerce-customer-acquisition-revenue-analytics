-- =============================================================================
-- Script: 08_Create_Analytical_Tables.sql
-- Layer : Analytical
-- Purpose: Build reusable business-level tables from staging data.
-- Run after 06_Load_Staging.sql. Requires MySQL 8.0+.
-- Definitions:
--   item_gmv = sum of item prices on delivered orders; excludes freight and
--              should not be described as net profit or audited revenue.
--   seller reconciliation checks a closed deal's seller_id against the seller
--   master; it does not prove marketing attribution was incorrect.
-- =============================================================================
USE olist_acquisition_revenue_analytics;

CREATE TABLE mart_monthly_performance AS
SELECT
    DATE_FORMAT(STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'), '%Y-%m') AS purchase_month,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    COUNT(*) AS delivered_order_item_rows,
    ROUND(SUM(CAST(NULLIF(oi.price, '') AS DECIMAL(12,2))), 2) AS item_gmv,
    ROUND(SUM(CAST(NULLIF(oi.freight_value, '') AS DECIMAL(12,2))), 2) AS freight_value
FROM stg_orders o
JOIN stg_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s') IS NOT NULL
GROUP BY DATE_FORMAT(STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'), '%Y-%m');

DROP TABLE IF EXISTS mart_seller_performance;
CREATE TABLE mart_seller_performance AS
SELECT
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COALESCE(k.delivered_orders, 0) AS delivered_orders,
    COALESCE(k.delivered_order_items, 0) AS delivered_order_items,
    COALESCE(k.item_gmv, 0.00) AS item_gmv,
    COALESCE(k.freight_value, 0.00) AS freight_value,
    k.average_item_price
FROM stg_sellers s
LEFT JOIN (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS delivered_orders,
        COUNT(*) AS delivered_order_items,
        ROUND(SUM(CAST(NULLIF(oi.price, '') AS DECIMAL(12,2))), 2) AS item_gmv,
        ROUND(SUM(CAST(NULLIF(oi.freight_value, '') AS DECIMAL(12,2))), 2) AS freight_value,
        ROUND(AVG(CAST(NULLIF(oi.price, '') AS DECIMAL(12,2))), 2) AS average_item_price
    FROM stg_order_items oi
    JOIN stg_orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
) k ON k.seller_id = s.seller_id;

DROP TABLE IF EXISTS mart_marketing_reconciliation;
CREATE TABLE mart_marketing_reconciliation AS
SELECT
    d.mql_id,
    d.seller_id,
    d.won_date,
    d.business_segment,
    CASE WHEN sm.seller_id IS NULL THEN 'NO_MATCHING_SELLER_MASTER'
         ELSE 'MATCHED_SELLER_MASTER' END AS seller_master_status,
    CASE WHEN tx.seller_id IS NULL THEN 'NO_MATCHING_TRANSACTION'
         ELSE 'MATCHED_TRANSACTION' END AS transaction_status,
    sm.seller_state,
    sm.seller_city
FROM stg_closed_deals d
LEFT JOIN stg_sellers sm ON sm.seller_id = d.seller_id
LEFT JOIN (
    SELECT DISTINCT seller_id
    FROM stg_order_items
    WHERE seller_id IS NOT NULL AND TRIM(seller_id) <> ''
) tx ON tx.seller_id = d.seller_id;

-- Preview the analytical tables and key marketing result.
SELECT * FROM mart_monthly_performance ORDER BY purchase_month;
SELECT * FROM mart_seller_performance ORDER BY item_gmv DESC LIMIT 10;
SELECT transaction_status, COUNT(*) AS deal_count
FROM mart_marketing_reconciliation
GROUP BY transaction_status
ORDER BY deal_count DESC;
