# Olist E-Commerce Customer Acquisition and Revenue Analytics

**Tools:** Python, Pandas, MySQL, SQL, Excel

## What this project looks at

Olist is a Brazilian online marketplace. This project uses two related datasets: one about businesses that showed interest in selling through Olist, and another about activity on the marketplace.

The main question is:

**Of the sellers who reached the “closed deal” stage in the marketing data, how many can we find in the marketplace transaction data?**

A closed deal does not automatically mean that a seller has started selling. A seller may need time to activate, the seller IDs may not match, or the seller may not have an order in the period covered by the data. Any missing match needs to be checked before drawing conclusions.

## Main numbers

- **8,000** marketing-qualified leads
- **842** closed deals
- **10.53%** closed-deal-to-lead ratio (842 divided by 8,000)
- **462** closed deals without a matching seller in the transaction data
- **54.87%** of closed deals had no transaction match (462 divided by 842)
- **11** source tables, with about **1.56 million rows** in total
- **1,000,163** rows in the geolocation file

These counts describe the supplied files and the recorded analysis. The 10.53% figure is a simple ratio, not proof that every lead and deal belongs to the same acquisition period. The 462 unmatched deals are a follow-up list, not proof that marketing attribution is wrong.

## What I did

1. Used Python and Pandas to check that the CSV files were present, readable, and had the expected columns and row counts.
2. Loaded the source data into MySQL.
3. Used SQL to check row counts, required IDs, duplicates, missing values, and links between tables.
4. Created staging tables and cleaned fields for analysis while keeping the raw tables available.
5. Queried the marketing funnel and compared closed deals with seller and transaction data.
6. Prepared an Excel workbook and presentation to share the results and suggested next steps.

## Data quality checks

The recorded validation run reported:

- No required-key failures
- No referential-integrity failures
- No source row-count mismatches
- 814 repeated review IDs that need interpretation
- 13 product categories without a matching English category translation

The review file originally loaded one row short in MySQL. The CSV loading settings were changed, and the load was checked again against the expected **99,224 rows**.

## Files in this project

```text
Raw_Data/          Original CSV files
Reference_Data/    Source row-count summary
Notebooks/         Python checks for source files
SQL/               MySQL setup, loading, validation, cleaning, and analysis
Docs/              Project notes and business recommendations
Excel/             Executive reporting workbook
Presentation/      Project slide deck
Reports/           Executive summary PDF
README.md          Project overview and run steps
```

## How to run the project

1. Install Python with Pandas and Jupyter Notebook, plus MySQL 8 and MySQL Workbench.
2. Keep the supplied CSV files in the `Raw_Data` folder. If you download the data separately, use the original Olist e-commerce and marketing-funnel files.
3. Open `Notebooks/01_Raw_Data_Ingestion.ipynb` and run the checks.
4. Open the SQL files in MySQL Workbench and run them in numerical order. Check the file paths in the load script before running it.
5. Run the validation scripts and review any warnings before using the analysis queries.
6. Run `SQL/11_Business_Analysis.sql` for the business queries.
7. Use the query results to update the Excel workbook and presentation when you rerun the project.

The files in this repository include a recorded set of results. If you rerun the analysis, your results may differ if you change the source files, filters, or query logic.

## Business next steps

1. Review the 462 closed deals without a transaction match.
2. Check seller IDs, deal dates, and the first transaction date before assigning a reason.
3. Agree on what counts as an activated seller. For example, a team could track whether a seller has a valid order within 30, 60, or 90 days of deal closure.
4. Report monthly orders, item GMV, average order value, freight, and review scores using the same definitions each month.
5. Keep the row-count and data-quality checks in place whenever the files are loaded again.

## Important definitions

- **Lead-to-deal ratio:** number of closed deals divided by the number of marketing-qualified leads.
- **Transaction match:** a closed deal whose seller can be matched to a seller in the marketplace transaction data.
- **Unmatched-deal share:** closed deals without a transaction match divided by all closed deals.
- **Item GMV:** the sum of item prices for the orders included in the query. It excludes freight and is not profit.
- **Average order value (AOV):** item GMV divided by the number of distinct orders, unless the report states another definition.

## Data source and limitations

- The project uses public Olist Brazilian e-commerce and marketing-funnel datasets distributed through Kaggle. The data describes historical activity, not current marketplace performance.

- A missing seller match does not by itself show why the match is missing. The project does not claim that marketing caused or failed to cause marketplace revenue. Profit also cannot be calculated from item prices alone because relevant costs and other adjustments are not included.


## Source links

- Olist datasets: <https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce>
- Olist marketing funnel dataset: <https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist>
