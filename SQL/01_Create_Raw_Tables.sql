-- =============================================================================
-- Script : 01_Create_Raw_Tables.sql
-- Layer  : Raw
-- Purpose: Create source-faithful raw tables only.
-- =============================================================================
USE olist_acquisition_revenue_analytics;

-- =========================================================
-- REFERENCE (not a raw source table)
-- Expected row counts reference from Notebook 01, loaded for validation
-- =========================================================
CREATE TABLE meta_expected_row_counts (
    `source`            VARCHAR(50),
    `table_name`        VARCHAR(100),
    `source_file`       VARCHAR(150),
    `exists_flag`       BOOLEAN,
    `size_mb`           DECIMAL(10, 2),
    `encoding_valid`    BOOLEAN,
    `delimiter`         VARCHAR(5),
    `delimiter_match`   BOOLEAN,
    `line_ending`       VARCHAR(10),
    `rows`              INT,
    `expected_rows`     INT,
    `row_count_match`   BOOLEAN,
    `columns`           INT,
    `expected_columns`  INT,
    `missing`           VARCHAR(500),
    `unexpected`        VARCHAR(500),
    `schema_match`      BOOLEAN,
    `duplicate_headers` INT,
    `csv_readable`      BOOLEAN,
    `parser_error`      VARCHAR(500),
    `status`            VARCHAR(20)
);

-- =========================================================
-- OLIST E-COMMERCE
-- =========================================================
CREATE TABLE raw_customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(20),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
  );

-- Sellers
CREATE TABLE raw_sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(20),
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
  );

-- Product category translation
CREATE TABLE raw_product_category_translation (
    product_category_name VARCHAR(150),
    product_category_name_english VARCHAR(150)
  );

-- Products
CREATE TABLE raw_products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(150),
    product_name_lenght VARCHAR(30),
    product_description_lenght VARCHAR(30),
    product_photos_qty VARCHAR(30),
    product_weight_g VARCHAR(30),
    product_length_cm VARCHAR(30),
    product_height_cm VARCHAR(30),
    product_width_cm VARCHAR(30)
  );

-- Orders
CREATE TABLE raw_orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp VARCHAR(50),
    order_approved_at VARCHAR(50),
    order_delivered_carrier_date VARCHAR(50),
    order_delivered_customer_date VARCHAR(50),
    order_estimated_delivery_date VARCHAR(50)
  );

-- Order items
CREATE TABLE raw_order_items (
    order_id VARCHAR(50),
    order_item_id VARCHAR(30),
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date VARCHAR(50),
    price VARCHAR(30),
    freight_value VARCHAR(30)
  );

-- Order payments
CREATE TABLE raw_order_payments (
    order_id VARCHAR(50),
    payment_sequential VARCHAR(30),
    payment_type VARCHAR(50),
    payment_installments VARCHAR(30),
    payment_value VARCHAR(30)
  );

-- Order reviews
CREATE TABLE raw_order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score VARCHAR(20),
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date VARCHAR(50),
    review_answer_timestamp VARCHAR(50)
  );

-- Geolocation
CREATE TABLE raw_geolocation (
    geolocation_zip_code_prefix VARCHAR(20),
    geolocation_lat VARCHAR(30),
    geolocation_lng VARCHAR(30),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(10)
  );

-- =========================================================
-- OLIST MARKETING FUNNEL
-- =========================================================
CREATE TABLE raw_marketing_qualified_leads (
    mql_id VARCHAR(50),
    first_contact_date VARCHAR(50),
    landing_page_id VARCHAR(100),
    origin VARCHAR(100)
  );

-- Closed deals
CREATE TABLE raw_closed_deals (
    mql_id VARCHAR(50),
    seller_id VARCHAR(50),
    sdr_id VARCHAR(50),
    sr_id VARCHAR(50),
    won_date VARCHAR(50),
    business_segment VARCHAR(150),
    lead_type VARCHAR(100),
    lead_behaviour_profile VARCHAR(100),
    has_company VARCHAR(20),
    has_gtin VARCHAR(20),
    average_stock VARCHAR(50),
    business_type VARCHAR(100),
    declared_product_catalog_size VARCHAR(50),
    declared_monthly_revenue VARCHAR(50)
  );