# Project: Olist Customer Acquisition and Revenue Analytics

## 1. What is this project about?

Olist is a Brazilian online marketplace. This project combines marketing-funnel data with marketplace data to answer one practical question:

**Can we find the sellers listed as closed deals in the marketing data in the marketplace transaction data?**

A seller may close a deal before starting to sell. There may also be a delay before the first order, or the seller ID may be recorded differently between systems. A missing match needs checking; it does not automatically mean that marketing attribution is wrong.

## 2. Questions covered

- How many marketing-qualified leads are in the source file?
- How many leads are recorded as closed deals?
- What is the closed-deal-to-lead ratio?
- How many closed deals have no matching seller in transaction data?
- What data checks are needed before using the results?
- What should the business investigate next?

## 3. Source data

The project uses 11 CSV tables.

| Table | Rows in the recorded source inventory | Contents |
| --- | ---: | --- |
| Customers | 99,441 | Customer records |
| Sellers | 3,095 | Seller records |
| Product categories | 71 | Category names and translations |
| Products | 32,951 | Product details |
| Orders | 99,441 | Order-level information |
| Order items | 112,650 | Items included in orders |
| Payments | 103,886 | Payment records |
| Reviews | 99,224 | Customer reviews |
| Geolocation | 1,000,163 | ZIP-code and location information |
| Marketing-qualified leads | 8,000 | Leads that reached the qualified stage |
| Closed deals | 842 | Leads recorded as closed deals |

The total is about 1.56 million rows across the 11 files. Because these files contain different types of records, the total is not a count of unique people, orders, or sellers.

## 4. Tools

- **Python and Pandas:** check that files can be read and have the expected columns and row counts.
- **MySQL:** store the source tables and prepare data for analysis.
- **SQL:** check data quality, clean staging tables, and calculate the main figures.
- **Excel:** show the results in a summary workbook.
- **PowerPoint:** explain the question, findings, and next steps.

## 5. Project steps

```text
CSV files
   ↓
Python file checks
   ↓
MySQL raw tables
   ↓
SQL data checks
   ↓
Staging and cleaning
   ↓
Business queries
   ↓
Excel summary and presentation
```

The raw tables keep the source values as loaded. Staging tables are used to standardise fields for analysis without changing the raw tables. The business queries count leads and deals, compare deals with seller records, and summarise marketplace activity.

## 6. Main results

| Measure | Result | Meaning |
| --- | ---: | --- |
| Marketing-qualified leads | 8,000 | Leads in the marketing file |
| Closed deals | 842 | Deals recorded as closed |
| Closed-deal-to-lead ratio | 10.53% | 842 divided by 8,000 |
| Closed deals without a transaction match | 462 | Closed deals for which no seller match was found |
| Share without a transaction match | 54.87% | 462 divided by 842 |
| Source tables | 11 | Tables included in the source inventory |
| Approximate total source rows | 1,559,764 | Sum of rows across the source files |
| Geolocation rows | 1,000,163 | Rows in the geolocation file |

- The 10.53% figure is a simple ratio. Before calling it a formal conversion rate, confirm that the lead and deal records use the intended join and time period.

- The 462 unmatched deals are the main follow-up item. Possible reasons include activation timing, seller ID mapping, the period covered by transaction data, or another data issue. The count alone does not tell us which reason applies.

## 7. Data checks and findings

The project checks for missing or blank values, required IDs, duplicate IDs, links between tables, source-to-database row counts, and loading warnings.

The recorded validation run reported:

- No required-key failures
- No referential-integrity failures
- No source row-count mismatches
- 814 repeated review IDs
- 13 product categories without a matching English translation

The repeated review IDs and missing translations should be reviewed in context rather than automatically deleted or treated as fatal errors.

### Review-file loading fix

The review CSV contains 99,224 rows. An earlier MySQL load brought in one fewer row because of how backslashes and quotes were interpreted. The load settings were changed, and the row count was checked again. The expected count was then reached.

### Geolocation file

The geolocation file contains 1,000,163 rows and may take longer to load or transform than the other files. If a client times out, check whether the query is still running and whether rows have already been loaded before trying again.

## 8. KPI definitions

- **Lead-to-deal ratio:** closed deals divided by marketing-qualified leads.
- **Transaction-match rate:** closed deals with a seller match divided by all closed deals.
- **Unmatched-deal share:** closed deals without a seller match divided by all closed deals.
- **Item GMV:** total item prices for the included orders. Freight is excluded; this is not profit.
- **Average order value:** item GMV divided by distinct orders, unless the report clearly states another definition.

Use the same filters and date range when comparing months.

## 9. Suggested next steps

1. Make a list of the 462 unmatched deals and review each one.
2. Check seller IDs, deal dates, seller records, and first transaction dates.
3. Assign a reason where possible, such as “activation pending,” “ID needs checking,” “no order in period,” or “unresolved.”
4. Agree on an activation rule, such as a valid order within 30, 60, or 90 days of deal closure.
5. Compare activation by deal month so recent deals are not judged using the same time window as older deals.
6. Keep the data checks as part of each new load.

These are suggested actions, not guaranteed results.

## 10. Limits of the analysis

- The files describe historical Olist activity, not current marketplace performance.
- A missing seller match does not explain why that seller is missing.
- The simple lead-to-deal ratio may not account for timing differences between leads and deals.
- Item GMV is not profit. Profit analysis would need costs, commissions, refunds, and other relevant data.
- A relationship between delivery measures and review scores does not prove that one caused the other.

## 11. How to rerun the project

1. Run `Notebooks/01_Raw_Data_Ingestion.ipynb`.
2. Run the SQL files in numeric order, starting with database setup and raw table creation.
3. Check the file paths in the loading script.
4. Run the validation and data-quality scripts.
5. Run the business analysis queries.
6. Update the Excel workbook and presentation using the new query results.

See `README.md` for the folder structure and setup overview.
