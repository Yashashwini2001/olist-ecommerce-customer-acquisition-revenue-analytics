-- =============================================================================
-- Script : 02_Load_Raw_Data.sql
-- Layer  : Raw
-- Purpose: Load original CSVs into raw tables (no cleaning/transform).
-- Paths: relative to SQL/; run client from SQL/ or use absolute paths.
-- Line endings: LF except CRLF for translation/reviews (verify on clone).
-- Verification: check SHOW COUNT(*) WARNINGS; reviews reconcile in validation.
-- =============================================================================
USE olist_acquisition_revenue_analytics;

-- ============================================================
-- REFERENCE DATA (row-count reconciliation baseline)
-- Exported by Notebook 01 and loaded first, for script 04.
-- The last column (status) is trimmed of any trailing CR/LF so the file loads
-- identically whether it was written with Windows (CRLF) or Unix (LF) endings.
-- ============================================================
TRUNCATE TABLE meta_expected_row_counts;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Reference_Data/raw_data_ingestion_summary.csv'
INTO TABLE meta_expected_row_counts
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(`source`, `table_name`, `source_file`, @exists_flag, `size_mb`, @encoding_valid, `delimiter`, @delimiter_match,
 `line_ending`, `rows`, `expected_rows`, @row_count_match, `columns`, `expected_columns`,
 `missing`, `unexpected`, @schema_match, `duplicate_headers`, @csv_readable, `parser_error`, @status)
SET `exists_flag`     = IF(LOWER(@exists_flag)      = 'true', 1, 0),
    `encoding_valid`  = IF(LOWER(@encoding_valid)   = 'true', 1, 0),
    `delimiter_match` = IF(LOWER(@delimiter_match)  = 'true', 1, 0),
    `row_count_match` = IF(LOWER(@row_count_match)  = 'true', 1, 0),
    `schema_match`    = IF(LOWER(@schema_match)     = 'true', 1, 0),
    `csv_readable`    = IF(LOWER(@csv_readable)     = 'true', 1, 0),
    `status`          = TRIM(TRAILING '\r' FROM TRIM(TRAILING '\n' FROM @status));
SHOW COUNT(*) WARNINGS;

-- ============================================================
-- OLIST E-COMMERCE
-- ============================================================

-- Customers | LF
TRUNCATE TABLE raw_customers;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_customers_dataset.csv'
INTO TABLE raw_customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city,
 customer_state);
SHOW COUNT(*) WARNINGS;

-- Sellers | LF
TRUNCATE TABLE raw_sellers;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_sellers_dataset.csv'
INTO TABLE raw_sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, seller_state);
SHOW COUNT(*) WARNINGS;

-- Product category translation | CRLF
TRUNCATE TABLE raw_product_category_translation;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/product_category_name_translation.csv'
INTO TABLE raw_product_category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(product_category_name, product_category_name_english);
SHOW COUNT(*) WARNINGS;

-- Products | LF
TRUNCATE TABLE raw_products;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_products_dataset.csv'
INTO TABLE raw_products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_category_name, product_name_lenght, product_description_lenght,
 product_photos_qty, product_weight_g, product_length_cm, product_height_cm,
 product_width_cm);
SHOW COUNT(*) WARNINGS;

-- Orders | LF
TRUNCATE TABLE raw_orders;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_orders_dataset.csv'
INTO TABLE raw_orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp,
 order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date);
SHOW COUNT(*) WARNINGS;

-- Order items | LF
TRUNCATE TABLE raw_order_items;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_order_items_dataset.csv'
INTO TABLE raw_order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id,
 shipping_limit_date, price, freight_value);
SHOW COUNT(*) WARNINGS;

-- Order payments | LF
TRUNCATE TABLE raw_order_payments;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_order_payments_dataset.csv'
INTO TABLE raw_order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_sequential, payment_type, payment_installments,
 payment_value);
SHOW COUNT(*) WARNINGS;

-- Order reviews | CRLF | ESCAPED BY '' (see header); watch warnings closely
TRUNCATE TABLE raw_order_reviews;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_order_reviews_dataset.csv'
INTO TABLE raw_order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, review_comment_title,
 review_comment_message, review_creation_date, review_answer_timestamp);
SHOW COUNT(*) WARNINGS;

-- Geolocation | LF
TRUNCATE TABLE raw_geolocation;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_geolocation_dataset.csv'
INTO TABLE raw_geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city,
 geolocation_state);
SHOW COUNT(*) WARNINGS;

-- ============================================================
-- OLIST MARKETING FUNNEL
-- ============================================================

-- Marketing qualified leads | LF
TRUNCATE TABLE raw_marketing_qualified_leads;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_marketing_qualified_leads_dataset.csv'
INTO TABLE raw_marketing_qualified_leads
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(mql_id, first_contact_date, landing_page_id, origin);
SHOW COUNT(*) WARNINGS;

-- Closed deals | LF
TRUNCATE TABLE raw_closed_deals;
LOAD DATA LOCAL INFILE 'C:/PORTFOLIO/olist_ecommerce_customer_acquisition_revenue_analytics/Raw_Data/olist_closed_deals_dataset.csv'
INTO TABLE raw_closed_deals
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(mql_id, seller_id, sdr_id, sr_id,
 won_date, business_segment, lead_type, lead_behaviour_profile,
 has_company, has_gtin, average_stock, business_type,
 declared_product_catalog_size, declared_monthly_revenue);
SHOW COUNT(*) WARNINGS;
