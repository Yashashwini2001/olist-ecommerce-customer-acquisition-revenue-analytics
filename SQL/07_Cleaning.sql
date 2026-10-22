-- =============================================================================
-- Script : 07_Cleaning.sql
-- Layer  : Cleaned
-- Purpose: Build typed, standardised, de-duplicated cln_* tables from the
--          untouched stg_* copy, and log every rule that changed anything.
-- Input  : stg_* (exact copy of raw, all text)
-- Output : cln_* tables (real data types, primary keys, indexes)
--          meta_cleaning_log (one row per rule: what it does, rows affected)
--
-- Principles
--   * stg_* is never modified, so any cleaned value can be traced back.
--   * Nothing is deleted without a rule in meta_cleaning_log.
--   * Genuine source anomalies are FLAGGED in a column, not deleted or
--     "corrected" (the data may be wrong, but it is still what happened).
--   * Missing values are NOT imputed. Where a field is missing for most rows
--     (e.g. closed_deals.has_company) the gap is itself information.
--   * Run time: about 1-2 minutes (geolocation has 1,000,163 rows).
--
-- CLEANING RULES (also written to meta_cleaning_log below)
--   R01 All text: TRIM; empty string -> NULL.
--   R02 Text -> real types: timestamps DATETIME, money DECIMAL(10,2), counts INT.
--   R03 State codes: UPPER case.
--   R04 products: misspelt source columns renamed (lenght -> length).
--   R05 products: impossible physical values (weight/dimension = 0) -> NULL.
--   R06 products: category translated to English; blank -> 'unknown';
--       untranslated names keep their Portuguese name.
--   R07 order_reviews: ONE review per ORDER. When an order has several, keep
--       the latest review_answer_timestamp (ties: latest creation, then
--       review_id). NOTE: the grain is order_id, NOT review_id - the source
--       reuses a review_id across different orders (789 ids, 814 extra rows),
--       and de-duplicating on review_id would delete 814 real reviews that
--       belong to other orders.
--   R08 orders: three source anomalies FLAGGED (not removed).
--   R09 order_payments: 0 instalments FLAGGED (not removed).
--   R10 marketing leads: blank origin -> 'unknown' (existing category).
--   R11 closed_deals: has_company / has_gtin text -> TINYINT (1/0/NULL).
--   R12 geolocation: coordinates rounded to 9 decimals (sub-millimetre).
-- =============================================================================
USE olist_acquisition_revenue_analytics;

-- ============================================================
-- 0. Reset (re-runnable)
-- ============================================================
DROP TABLE IF EXISTS meta_cleaning_log;
DROP TABLE IF EXISTS cln_customers;
DROP TABLE IF EXISTS cln_sellers;
DROP TABLE IF EXISTS cln_product_category_translation;
DROP TABLE IF EXISTS cln_products;
DROP TABLE IF EXISTS cln_orders;
DROP TABLE IF EXISTS cln_order_items;
DROP TABLE IF EXISTS cln_order_payments;
DROP TABLE IF EXISTS cln_order_reviews;
DROP TABLE IF EXISTS cln_geolocation;
DROP TABLE IF EXISTS cln_marketing_qualified_leads;
DROP TABLE IF EXISTS cln_closed_deals;

-- ============================================================
-- 1. Tables
-- ============================================================
CREATE TABLE cln_customers (
    customer_id        VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50) NOT NULL,
    zip_code_prefix    VARCHAR(10) NULL,
    city               VARCHAR(100) NULL,
    state              CHAR(2) NULL,
    PRIMARY KEY (customer_id),
    KEY ix_customers_unique (customer_unique_id)
);

CREATE TABLE cln_sellers (
    seller_id       VARCHAR(50) NOT NULL,
    zip_code_prefix VARCHAR(10) NULL,
    city            VARCHAR(100) NULL,
    state           CHAR(2) NULL,
    PRIMARY KEY (seller_id)
);

CREATE TABLE cln_product_category_translation (
    category_pt VARCHAR(150) NOT NULL,
    category_en VARCHAR(150) NOT NULL,
    PRIMARY KEY (category_pt)
);

CREATE TABLE cln_products (
    product_id         VARCHAR(50) NOT NULL,
    category_pt        VARCHAR(150) NULL,
    category_en        VARCHAR(150) NOT NULL,
    name_length        INT NULL,
    description_length INT NULL,
    photos_qty         INT NULL,
    weight_g           INT NULL,
    length_cm          INT NULL,
    height_cm          INT NULL,
    width_cm           INT NULL,
    PRIMARY KEY (product_id)
);

CREATE TABLE cln_orders (
    order_id                       VARCHAR(50) NOT NULL,
    customer_id                    VARCHAR(50) NOT NULL,
    order_status                   VARCHAR(30) NOT NULL,
    purchase_ts                    DATETIME NOT NULL,
    approved_ts                    DATETIME NULL,
    delivered_carrier_ts           DATETIME NULL,
    delivered_customer_ts          DATETIME NULL,
    estimated_delivery_ts          DATETIME NULL,
    flag_carrier_before_purchase   TINYINT NOT NULL,
    flag_delivered_without_date    TINYINT NOT NULL,
    flag_nondelivered_with_date    TINYINT NOT NULL,
    PRIMARY KEY (order_id),
    KEY ix_orders_customer (customer_id),
    KEY ix_orders_purchase (purchase_ts)
);

CREATE TABLE cln_order_items (
    order_id            VARCHAR(50) NOT NULL,
    order_item_id       INT NOT NULL,
    product_id          VARCHAR(50) NOT NULL,
    seller_id           VARCHAR(50) NOT NULL,
    shipping_limit_ts   DATETIME NULL,
    price               DECIMAL(10, 2) NOT NULL,
    freight_value       DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    KEY ix_items_seller (seller_id),
    KEY ix_items_product (product_id)
);

CREATE TABLE cln_order_payments (
    order_id               VARCHAR(50) NOT NULL,
    payment_sequential     INT NOT NULL,
    payment_type           VARCHAR(30) NOT NULL,
    payment_installments   INT NOT NULL,
    payment_value          DECIMAL(10, 2) NOT NULL,
    flag_zero_installments TINYINT NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE cln_order_reviews (
    order_id        VARCHAR(50) NOT NULL,
    review_id       VARCHAR(50) NOT NULL,   -- NOT unique: the source reuses ids across orders
    review_score    TINYINT NOT NULL,
    comment_title   TEXT NULL,
    comment_message TEXT NULL,
    creation_ts     DATETIME NOT NULL,
    answer_ts       DATETIME NOT NULL,
    PRIMARY KEY (order_id)
);

CREATE TABLE cln_geolocation (
    zip_code_prefix VARCHAR(10) NOT NULL,
    lat             DECIMAL(12, 9) NOT NULL,
    lng             DECIMAL(12, 9) NOT NULL,
    city            VARCHAR(100) NULL,
    state           CHAR(2) NULL,
    KEY ix_geo_zip (zip_code_prefix)
);

CREATE TABLE cln_marketing_qualified_leads (
    mql_id             VARCHAR(50) NOT NULL,
    first_contact_date DATE NOT NULL,
    landing_page_id    VARCHAR(100) NULL,
    origin             VARCHAR(100) NOT NULL,
    PRIMARY KEY (mql_id)
);

CREATE TABLE cln_closed_deals (
    mql_id                        VARCHAR(50) NOT NULL,
    seller_id                     VARCHAR(50) NOT NULL,
    sdr_id                        VARCHAR(50) NULL,
    sr_id                         VARCHAR(50) NULL,
    won_ts                        DATETIME NOT NULL,
    business_segment              VARCHAR(150) NULL,
    lead_type                     VARCHAR(100) NULL,
    lead_behaviour_profile        VARCHAR(100) NULL,
    has_company                   TINYINT NULL,
    has_gtin                      TINYINT NULL,
    average_stock                 VARCHAR(50) NULL,
    business_type                 VARCHAR(100) NULL,
    declared_product_catalog_size DECIMAL(12, 1) NULL,
    declared_monthly_revenue      DECIMAL(14, 2) NULL,
    PRIMARY KEY (mql_id),
    KEY ix_deals_seller (seller_id)
);

-- ============================================================
-- 2. Populate (stg_* -> cln_*)
-- ============================================================
INSERT INTO cln_customers (customer_id, customer_unique_id, zip_code_prefix, city, state)
SELECT TRIM(customer_id), TRIM(customer_unique_id),
       NULLIF(TRIM(customer_zip_code_prefix), ''),
       NULLIF(TRIM(customer_city), ''),
       UPPER(NULLIF(TRIM(customer_state), ''))
FROM stg_customers;

INSERT INTO cln_sellers (seller_id, zip_code_prefix, city, state)
SELECT TRIM(seller_id),
       NULLIF(TRIM(seller_zip_code_prefix), ''),
       NULLIF(TRIM(seller_city), ''),
       UPPER(NULLIF(TRIM(seller_state), ''))
FROM stg_sellers;

INSERT INTO cln_product_category_translation (category_pt, category_en)
SELECT TRIM(product_category_name), TRIM(product_category_name_english)
FROM stg_product_category_translation;

INSERT INTO cln_products (product_id, category_pt, category_en, name_length, description_length,
                          photos_qty, weight_g, length_cm, height_cm, width_cm)
SELECT TRIM(p.product_id),
       NULLIF(TRIM(p.product_category_name), ''),
       COALESCE(t.category_en, NULLIF(TRIM(p.product_category_name), ''), 'unknown'),
       CAST(NULLIF(TRIM(p.product_name_lenght), '') AS UNSIGNED),
       CAST(NULLIF(TRIM(p.product_description_lenght), '') AS UNSIGNED),
       CAST(NULLIF(TRIM(p.product_photos_qty), '') AS UNSIGNED),
       NULLIF(CAST(NULLIF(TRIM(p.product_weight_g), '') AS UNSIGNED), 0),
       NULLIF(CAST(NULLIF(TRIM(p.product_length_cm), '') AS UNSIGNED), 0),
       NULLIF(CAST(NULLIF(TRIM(p.product_height_cm), '') AS UNSIGNED), 0),
       NULLIF(CAST(NULLIF(TRIM(p.product_width_cm), '') AS UNSIGNED), 0)
FROM stg_products AS p
LEFT JOIN cln_product_category_translation AS t
       ON t.category_pt = TRIM(p.product_category_name);

INSERT INTO cln_orders (order_id, customer_id, order_status, purchase_ts, approved_ts,
                        delivered_carrier_ts, delivered_customer_ts, estimated_delivery_ts,
                        flag_carrier_before_purchase, flag_delivered_without_date,
                        flag_nondelivered_with_date)
SELECT order_id, customer_id, order_status, purchase_ts, approved_ts,
       delivered_carrier_ts, delivered_customer_ts, estimated_delivery_ts,
       COALESCE(delivered_carrier_ts < purchase_ts, 0),
       (order_status = 'delivered' AND delivered_customer_ts IS NULL),
       (order_status <> 'delivered' AND delivered_customer_ts IS NOT NULL)
FROM (
    SELECT TRIM(order_id)    AS order_id,
           TRIM(customer_id) AS customer_id,
           LOWER(TRIM(order_status)) AS order_status,
           STR_TO_DATE(NULLIF(TRIM(order_purchase_timestamp), ''),      '%Y-%m-%d %H:%i:%s') AS purchase_ts,
           STR_TO_DATE(NULLIF(TRIM(order_approved_at), ''),             '%Y-%m-%d %H:%i:%s') AS approved_ts,
           STR_TO_DATE(NULLIF(TRIM(order_delivered_carrier_date), ''),  '%Y-%m-%d %H:%i:%s') AS delivered_carrier_ts,
           STR_TO_DATE(NULLIF(TRIM(order_delivered_customer_date), ''), '%Y-%m-%d %H:%i:%s') AS delivered_customer_ts,
           STR_TO_DATE(NULLIF(TRIM(order_estimated_delivery_date), ''), '%Y-%m-%d %H:%i:%s') AS estimated_delivery_ts
    FROM stg_orders
) AS o;

INSERT INTO cln_order_items (order_id, order_item_id, product_id, seller_id, shipping_limit_ts, price, freight_value)
SELECT TRIM(order_id),
       CAST(TRIM(order_item_id) AS UNSIGNED),
       TRIM(product_id),
       TRIM(seller_id),
       STR_TO_DATE(NULLIF(TRIM(shipping_limit_date), ''), '%Y-%m-%d %H:%i:%s'),
       CAST(TRIM(price) AS DECIMAL(10, 2)),
       CAST(TRIM(freight_value) AS DECIMAL(10, 2))
FROM stg_order_items;

INSERT INTO cln_order_payments (order_id, payment_sequential, payment_type, payment_installments,
                                payment_value, flag_zero_installments)
SELECT TRIM(order_id),
       CAST(TRIM(payment_sequential) AS UNSIGNED),
       LOWER(TRIM(payment_type)),
       CAST(TRIM(payment_installments) AS UNSIGNED),
       CAST(TRIM(payment_value) AS DECIMAL(10, 2)),
       (CAST(TRIM(payment_installments) AS UNSIGNED) < 1)
FROM stg_order_payments;

-- R07: one review per order (latest answer wins)
INSERT INTO cln_order_reviews (order_id, review_id, review_score, comment_title, comment_message,
                               creation_ts, answer_ts)
SELECT order_id, review_id, review_score, comment_title, comment_message, creation_ts, answer_ts
FROM (
    SELECT TRIM(order_id)  AS order_id,
           TRIM(review_id) AS review_id,
           CAST(TRIM(review_score) AS UNSIGNED) AS review_score,
           NULLIF(TRIM(review_comment_title), '')   AS comment_title,
           NULLIF(TRIM(review_comment_message), '') AS comment_message,
           STR_TO_DATE(TRIM(review_creation_date),    '%Y-%m-%d %H:%i:%s') AS creation_ts,
           STR_TO_DATE(TRIM(review_answer_timestamp), '%Y-%m-%d %H:%i:%s') AS answer_ts,
           ROW_NUMBER() OVER (
               PARTITION BY TRIM(order_id)
               ORDER BY STR_TO_DATE(TRIM(review_answer_timestamp), '%Y-%m-%d %H:%i:%s') DESC,
                        STR_TO_DATE(TRIM(review_creation_date),    '%Y-%m-%d %H:%i:%s') DESC,
                        TRIM(review_id) DESC
           ) AS rn
    FROM stg_order_reviews
) AS ranked
WHERE rn = 1;

INSERT INTO cln_geolocation (zip_code_prefix, lat, lng, city, state)
SELECT TRIM(geolocation_zip_code_prefix),
       CAST(TRIM(geolocation_lat) AS DECIMAL(12, 9)),
       CAST(TRIM(geolocation_lng) AS DECIMAL(12, 9)),
       NULLIF(TRIM(geolocation_city), ''),
       UPPER(NULLIF(TRIM(geolocation_state), ''))
FROM stg_geolocation;

INSERT INTO cln_marketing_qualified_leads (mql_id, first_contact_date, landing_page_id, origin)
SELECT TRIM(mql_id),
       STR_TO_DATE(TRIM(first_contact_date), '%Y-%m-%d'),
       NULLIF(TRIM(landing_page_id), ''),
       COALESCE(NULLIF(LOWER(TRIM(origin)), ''), 'unknown')
FROM stg_marketing_qualified_leads;

INSERT INTO cln_closed_deals (mql_id, seller_id, sdr_id, sr_id, won_ts, business_segment, lead_type,
                              lead_behaviour_profile, has_company, has_gtin, average_stock, business_type,
                              declared_product_catalog_size, declared_monthly_revenue)
SELECT TRIM(mql_id),
       TRIM(seller_id),
       NULLIF(TRIM(sdr_id), ''),
       NULLIF(TRIM(sr_id), ''),
       STR_TO_DATE(TRIM(won_date), '%Y-%m-%d %H:%i:%s'),
       NULLIF(TRIM(business_segment), ''),
       NULLIF(TRIM(lead_type), ''),
       NULLIF(TRIM(lead_behaviour_profile), ''),
       CASE LOWER(TRIM(has_company)) WHEN 'true' THEN 1 WHEN 'false' THEN 0 ELSE NULL END,
       CASE LOWER(TRIM(has_gtin))    WHEN 'true' THEN 1 WHEN 'false' THEN 0 ELSE NULL END,
       NULLIF(TRIM(average_stock), ''),
       NULLIF(TRIM(business_type), ''),
       CAST(NULLIF(TRIM(declared_product_catalog_size), '') AS DECIMAL(12, 1)),
       CAST(NULLIF(TRIM(declared_monthly_revenue), '') AS DECIMAL(14, 2))
FROM stg_closed_deals;

-- ============================================================
-- 3. Cleaning audit log - what each rule changed, measured from stg_*
-- ============================================================
CREATE TABLE meta_cleaning_log (
    rule_id       VARCHAR(5)   NOT NULL,
    table_name    VARCHAR(60)  NOT NULL,
    rule          VARCHAR(200) NOT NULL,
    action        VARCHAR(20)  NOT NULL,   -- NULLED / REMOVED / FLAGGED / MAPPED / TRIMMED
    rows_affected BIGINT       NOT NULL,
    PRIMARY KEY (rule_id, table_name)
);

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R05', 'cln_products', 'weight or dimension of 0 is physically impossible -> NULL', 'NULLED', COUNT(*)
FROM stg_products
WHERE TRIM(product_weight_g) = '0' OR TRIM(product_length_cm) = '0'
   OR TRIM(product_height_cm) = '0' OR TRIM(product_width_cm) = '0';

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R06a', 'cln_products', 'category has no English translation (kept Portuguese name)', 'MAPPED', COUNT(*)
FROM cln_products AS p
LEFT JOIN cln_product_category_translation AS t ON t.category_pt = p.category_pt
WHERE p.category_pt IS NOT NULL AND t.category_pt IS NULL;

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R06b', 'cln_products', 'blank category -> ''unknown''', 'MAPPED', COUNT(*)
FROM cln_products
WHERE category_pt IS NULL;

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R07', 'cln_order_reviews', 'order with several reviews: keep latest review_answer_timestamp, drop earlier ones', 'REMOVED',
       (SELECT COUNT(*) FROM stg_order_reviews) - (SELECT COUNT(*) FROM cln_order_reviews);

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R07b', 'cln_order_reviews', 'review_id reused across different orders (kept: each belongs to a different order)', 'FLAGGED',
       COUNT(*) - COUNT(DISTINCT review_id)
FROM cln_order_reviews;

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R07c', 'cln_order_reviews', 'blank review comment title / message -> NULL (counted as title + message cells)', 'NULLED',
       SUM(TRIM(review_comment_title) = '') + SUM(TRIM(review_comment_message) = '')
FROM stg_order_reviews;

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R01', 'text columns (all tables)', 'leading/trailing spaces removed (review title 1,996 / message 8,111 / geolocation city 1 at profiling)', 'TRIMMED',
       (SELECT COUNT(*) FROM stg_order_reviews
         WHERE CHAR_LENGTH(review_comment_title) <> CHAR_LENGTH(TRIM(review_comment_title))
            OR CHAR_LENGTH(review_comment_message) <> CHAR_LENGTH(TRIM(review_comment_message)))
     + (SELECT COUNT(*) FROM stg_geolocation
         WHERE CHAR_LENGTH(geolocation_city) <> CHAR_LENGTH(TRIM(geolocation_city)));

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R08a', 'cln_orders', 'carrier handover date earlier than purchase date', 'FLAGGED', SUM(flag_carrier_before_purchase) FROM cln_orders;
INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R08b', 'cln_orders', 'status delivered but no customer delivery date', 'FLAGGED', SUM(flag_delivered_without_date) FROM cln_orders;
INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R08c', 'cln_orders', 'status not delivered but customer delivery date present', 'FLAGGED', SUM(flag_nondelivered_with_date) FROM cln_orders;

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R09', 'cln_order_payments', 'payment with 0 instalments', 'FLAGGED', SUM(flag_zero_installments) FROM cln_order_payments;

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R10', 'cln_marketing_qualified_leads', 'blank origin -> ''unknown''', 'MAPPED', COUNT(*)
FROM stg_marketing_qualified_leads WHERE TRIM(origin) = '';

INSERT INTO meta_cleaning_log (rule_id, table_name, rule, action, rows_affected)
SELECT 'R11', 'cln_closed_deals', 'has_company / has_gtin / average_stock / catalog size left NULL when blank (not imputed; >90% blank)', 'NULLED',
       SUM(TRIM(has_company) = '')
FROM stg_closed_deals;

-- ============================================================
-- 4. Result: the audit log
-- ============================================================
SELECT rule_id, table_name, action, rows_affected, rule
FROM meta_cleaning_log
ORDER BY rule_id, table_name;
