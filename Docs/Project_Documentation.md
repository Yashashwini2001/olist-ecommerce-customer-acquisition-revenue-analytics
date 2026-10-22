# Project Documentation — Olist Customer Acquisition & Revenue Analytics

This document outlines the business context, data architecture, analytical workflow, data quality controls, validation results, and current project status.

---

## 1. Business Context

Olist, a Brazilian e-commerce marketplace, acquires sellers through a marketing funnel. This project aims to connect seller acquisition with downstream marketplace activity to determine if acquired sellers create meaningful business value.

### Business Question

Do sellers acquired through the marketing funnel contribute meaningful downstream marketplace value?

### Seller Value Journey

```mermaid
flowchart LR
    A[Seller Acquisition] --> B[Marketplace Activity]
    B --> C[Orders]
    C --> D[Revenue]
    D --> E[Delivery]
    E --> F[Customer Reviews]
```

---

## 2. Business Objectives

- Measure seller acquisition and conversion.
- Connect acquired sellers with marketplace activity.
- Measure seller orders and revenue contribution.
- Evaluate delivery performance and customer satisfaction.
- Identify high-value and underperforming sellers.
- Translate findings into business recommendations.

---

## 3. Data Sources

| Dataset                   | Source           | Rows | Grain           |
| ------------------------- | ---------------- | ----: | --------------- |
| Customers                 | E-Commerce       | 99,441 | Customer        |
| Sellers                   | E-Commerce       |  3,095 | Seller          |
| Product Categories        | E-Commerce       |     71 | Category        |
| Products                  | E-Commerce       | 32,951 | Product         |
| Orders                    | E-Commerce       | 99,441 | Order           |
| Order Items               | E-Commerce       | 112,650 | Order + Item    |
| Payments                  | E-Commerce       | 103,886 | Order + Payment |
| Reviews                   | E-Commerce       | 99,224 | Review          |
| Geolocation               | E-Commerce       |1,000,163 | ZIP + Location  |
| Marketing Qualified Leads | Marketing Funnel |  8,000 | Lead            |
| Closed Deals              | Marketing Funnel |   842 | Closed Lead     |

---

## 4. Data Architecture

The project uses an ELT approach. Source files are loaded into MySQL first, with transformations performed afterward using SQL.

```text
Raw CSV Files
      ↓
Python Source Validation
      ↓
MySQL Raw Layer
      ↓
Raw Profiling
      ↓
Raw Validation
      ↓
Staging Layer
      ↓
SQL Cleaning
      ↓
Business Analysis
      ↓
Excel Reporting
```

### Data Layers

| Layer                      | Purpose                                  |
| -------------------------- | ---------------------------------------- |
| `raw_*`                    | Preserve source data as loaded           |
| `meta_expected_row_counts` | Reconcile source and database row counts |
| `stg_*`                    | Clean and standardize data               |
| Analytical SQL             | Develop KPIs and business insights       |

Raw tables remain unchanged after loading.

---

## 5. Notebook and SQL Responsibilities

The project uses one Python notebook and SQL for the remaining workflow.

### Python

`01_Raw_Data_Ingestion.ipynb`

Responsible for:

- File existence and readability
- Encoding validation
- Delimiter validation
- Header and schema validation
- Logical row-count validation
- Ingestion summary generation

Python stops after source validation.

### SQL

| Script                         | Purpose                               |
| ------------------------------ | ------------------------------------- |
| `00_Database_Setup.sql`        | Database setup and environment checks |
| `01_Create_Raw_Tables.sql`     | Raw table creation                    |
| `02_Load_Raw_Data.sql`         | Raw CSV loading                       |
| `03_Raw_Data_Profiling.sql`    | Raw data profiling                    |
| `04_Raw_Data_Validation.sql`   | Data-quality and integrity validation |
| `05_Create_Staging_Tables.sql` | Staging table creation                |

SQL becomes the analytical source of truth after ingestion.

---

## 6. Raw Layer

Raw tables preserve source values without cleaning or transformation.

The raw layer intentionally uses source-faithful structures and does not apply business rules, type conversions, deduplication, or standardization.

### Idempotent Loading

`02_Load_Raw_Data.sql` uses:

```text
TRUNCATE → LOAD DATA → Warning Check
```

This allows the raw layer to be safely reloaded without accumulating duplicate rows.

---

## 7. Order Reviews Load Issue

`order_reviews` initially loaded with 99,223 rows instead of 99,224.

### Root Cause

The source contains a literal trailing backslash before a closing quote. MySQL's default backslash escaping caused the CSV parser to interpret the quote incorrectly.

### Resolution

The `order_reviews` load uses:

```sql
ESCAPED BY ''
```

This disables backslash escaping and preserves the source value correctly.

### Verification

After the fix:

- Rows loaded: 99,224
- Load warnings: 0
- Review content preserved

This fix avoids unnecessary Python preprocessing of the raw file.

---

## 8. Raw Data Profiling

`03_Raw_Data_Profiling.sql` describes the loaded data without modifying it.

The profiling covers:

- Row counts
- NULL and blank values
- Distinct values
- Business-key distributions
- Numeric field summaries
- Date-value boundaries
- Data patterns requiring further investigation

### Key Findings

- `order_approved_at`: 160 blank values
- `order_delivered_carrier_date`: 1,783 blank values
- `order_delivered_customer_date`: 2,965 blank values
- `review_comment_title`: 87,658 blank values
- `review_comment_message`: 58,256 blank values
- `product_category_name`: 610 blank values
- `order_items.price`: R$0.85–R$6,735.00
- Average review score: approximately 4.09 / 5

These findings are treated as profiling observations rather than automatic data-quality failures.

---

## 9. Raw Data Validation

`04_Raw_Data_Validation.sql` validates whether the raw layer is suitable for downstream analysis.

### Validation Areas

1. Required keys
2. Duplicate business keys
3. Referential integrity
4. Marketing funnel coverage
5. Source-to-database row counts
6. Review content integrity
7. Overall validation status

### Current Results

| Check                                 | Result |
| ------------------------------------- | ------ |
| Required-key failures                 | 0      |
| Referential-integrity failures        | 0      |
| Row-count mismatches                  | 0      |
| Review content failures               | 0      |
| Duplicate review IDs                  | 814    |
| Missing product-category translations | 13     |
| Closed deals without matching sellers | 462    |

The duplicate review IDs and unmatched business relationships are documented findings, not raw-load failures.

---

 ## 10. Important Business Finding

462 of 842 closed deals do not have a matching seller in the transactional seller dataset.

This means approximately 45% of closed deals are currently joinable to marketplace seller activity.

This is important for the main business question because acquisition-to-revenue analysis cannot assume that every closed marketing deal became an active transactional seller.

---

 ## 11. Staging Layer

`05_Create_Staging_Tables.sql` currently creates empty staging structures using:

```sql
CREATE TABLE stg_* LIKE raw_*;
```

No cleaning is performed in the raw layer.

The next staging phase will:

- Load raw data into staging
- Standardize data types
- Clean values
- Resolve duplicate reviews
- Apply domain validation
- Validate the cleaned data

---

 ## 12. Project Status

### Implemented

- Source-file validation
- MySQL database setup
- Raw table creation
- Idempotent raw loading
- Raw profiling
- Raw validation
- Staging table structures
- Git hygiene

### Planned

- Staging data load
- Data cleaning and standardization
- Post-cleaning validation
- Analytical SQL
- KPI development
- Excel dashboard
- Business insights
- Executive presentation

---

 ## 13. Limitations

- Acquisition-to-revenue analysis is limited by the 462 closed deals without matching transactional sellers.
- Some geolocation records require further validation.
- Raw validation performance can be improved with appropriate non-unique indexes.
- `LOAD DATA LOCAL INFILE` paths depend on the SQL client's working directory.
- Source row-count references must be regenerated when source files change.

---

 ## 14. Expected Business Outcome

The final analysis will evaluate the seller journey from acquisition through marketplace performance and identify:

- Effective acquisition channels
- High-value sellers
- Underperforming sellers
- Revenue opportunities
- Operational issues
- Delivery and customer-experience relationships

The final deliverable will translate these findings into clear, actionable business recommendations.

---

 ## 15. Technology

| Technology       | Role                                               |
| ---------------- | -------------------------------------------------- |
| MySQL 8.0        | Database and primary analytical platform           |
| SQL              | Profiling, validation, transformation and analysis |
| Python / Pandas  | Source-file validation                             |
| Jupyter Notebook | Ingestion workflow                                 |
| Excel            | Business reporting                                 |
| Git / GitHub     | Version control                                    |