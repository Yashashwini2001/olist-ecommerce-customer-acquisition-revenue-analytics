# Olist E-Commerce Customer Acquisition and Revenue Analytics

**Python · Pandas · SQL · MySQL · Excel · ELT**

This project connects Olist's marketing acquisition funnel with downstream marketplace activity. The goal is to understand how many marketing-qualified leads become closed deals, whether acquired sellers can be found in transaction records, and how marketplace performance can be monitored with clear, repeatable KPIs.

## The business question

**Do sellers acquired through the marketing funnel show up in marketplace transaction data, and what should the business investigate when they do not?**

A seller not appearing in transaction records is a reconciliation gap to investigate—not automatic proof that marketing attribution is wrong. Timing, seller activation, identifier mapping, and the analysis window can all affect the result.

## Key findings

- The source inventory covers **11 CSV tables** and approximately **1.46 million source rows** in total.
- The marketing funnel dataset contains **8,000 marketing-qualified leads** and **842 closed deals**. The simple closed-deal-to-lead ratio is approximately **10.5%**; validate the funnel join logic before interpreting this as a formal conversion rate.
- The reported reconciliation found **462 of 842 closed deals (about 55%)** without a matching seller in transactional data. This is the central investigation opportunity in the project.
- The geolocation source contains **1,000,163 rows**, so row-count reconciliation and careful handling of long-running SQL statements matter.
- A previous `order_reviews` load silently missed one row because of CSV escape-character interpretation. The loading configuration was corrected and the expected **99,224 rows** were verified.
- Project documentation reports zero required-key failures, zero referential-integrity failures, and zero source row-count mismatches in the documented validation run. It also flags 814 duplicate review IDs and 13 category translations that need interpretation rather than automatic deletion.

## Project workflow

1. **Python / Pandas** — check source file availability, readability, headers, expected columns, row counts, and basic CSV integrity.
2. **MySQL raw layer** — load source files without business transformations.
3. **SQL profiling and validation** — inspect nulls, duplicates, keys, row counts, and relationships.
4. **Staging and cleaning** — standardise fields for analysis while preserving the raw layer.
5. **Business analysis** — query the acquisition funnel, seller matches, monthly orders, item GMV, delivery status, and review scores.
6. **Reporting** — use the Excel workbook and slide deck to communicate findings, caveats, and actions.

## Repository structure

```text
.
├── Raw_Data/                 # Source CSV files
├── Reference_Data/            # Ingestion summary and expected counts
├── Notebooks/                 # Python source validation notebook
├── SQL/                       # Database setup, load, cleaning, checks, analysis
├── Excel/
│   └── Olist_Executive_Reporting.xlsx
├── Presentation/
│   └── Olist_Customer_Acquisition_Analytics.pptx
└── README.md
```

## How to run

1. Download the two public Olist datasets from Kaggle and place all CSV files in `Raw_Data/`.
2. Open `Notebooks/01_Raw_Data_Ingestion.ipynb` and run the notebook to validate source files.
3. Open MySQL Workbench and execute the SQL scripts in numerical order. Review each script's comments and confirm the database path before loading.
4. Run the data-quality checks before business analysis.
5. Execute `SQL/11_Business_Analysis.sql` and use the query results to populate the monthly trend template in the Excel workbook.
6. Review the executive workbook and presentation. Replace any illustrative/template sections with the latest output from your own database run.

### Geolocation load troubleshooting

The geolocation CSV has 1,000,163 rows. A single large `INSERT ... SELECT` can exceed a client read timeout or expose server resource limits. If Error 2013 occurs, increase the Workbench DBMS read timeout, confirm whether the server query is still running before retrying, and use a repeatable batch strategy if needed. After loading, compare staging and cleaned row counts. Avoid rerunning a batch that has already committed.

## Main business recommendations

1. Build a weekly report for the 462 closed deals without a transaction match. Assign each case a reason such as activation pending, seller-ID mismatch, no order in the observation window, or unresolved.
2. Define seller activation as a measurable event—for example, the first valid order within a chosen number of days after deal closure—and report 30/60/90-day cohorts.
3. Maintain a documented seller-ID crosswalk between CRM/marketing and marketplace tables. Do not silently use fuzzy matching.
4. Track monthly delivered orders, item GMV, average order value, freight value, and review scores together. Item GMV is not profit and excludes freight.
5. Keep ingestion gates: expected row counts, load warnings, required keys, duplicate checks, and referential-integrity checks should be reviewed after reloads.

## KPI definitions

| KPI | Definition | Important note |
| --- | --- | --- |
| Lead-to-deal ratio | Distinct closed deals / distinct marketing-qualified leads | Interpret only after confirming the join and cohort logic |
| Transaction-match rate | Closed deals with a seller found in transaction records / closed deals | Requires consistent seller IDs and a defined observation window |
| Unmatched-deal share | Closed deals without a transaction match / all closed deals | A diagnostic measure, not a direct measure of marketing failure |
| Item GMV | Sum of item prices for included orders | Excludes freight and is not profit |
| Average order value (AOV) | Item GMV / distinct orders | State clearly whether freight is included |
| Delivery performance | Order counts by status and defined delivery-time measures | Do not mix cancelled, unavailable, and delivered orders without clear definitions |

## Tools

- Python and Pandas
- Jupyter Notebook
- MySQL 8 and SQL
- Microsoft Excel
- Git and GitHub

## Data and limitations

The project uses public, anonymised Olist Brazilian e-commerce and marketing-funnel datasets. Results describe the supplied historical dataset and should not be presented as current marketplace performance. Missing transaction matches do not establish causation or prove incorrect attribution. Business recommendations are proposed actions to test, not guaranteed outcomes.

## Portfolio / resume summary

Built a layered MySQL ELT workflow across 11 source tables and approximately 1.46 million records, adding checks for schema conformity, row counts, duplicates, nulls, and referential integrity. Diagnosed a silent CSV-loading truncation caused by MySQL escape-character handling. Reconciled marketing closed deals against seller transaction records and identified 462 of 842 deals without a transactional match, creating a clear follow-up investigation for marketing operations and seller activation.

## Attribution

- Olist Brazilian E-Commerce dataset and Olist Marketing Funnel dataset, publicly distributed through Kaggle.
- Repository: <https://github.com/Yashashwini2001/olist-ecommerce-customer-acquisition-revenue-analytics>
