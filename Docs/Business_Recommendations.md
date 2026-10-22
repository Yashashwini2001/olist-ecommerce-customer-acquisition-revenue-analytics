# Business Next Steps

These are practical things to check based on the current results. They are suggestions, not guaranteed outcomes.

## 1. Check the 462 unmatched closed deals

The analysis found 462 of 842 closed deals without a matching seller in transaction data. Start with a spreadsheet containing the deal ID, seller ID if available, deal date, seller match result, first order date if available, and review status.

Possible reason labels:

- Activation still pending
- Seller ID needs checking
- No order found in the period covered
- Seller or deal record needs checking
- Still unresolved

**Track:** how many cases have been reviewed and how many remain unresolved.

A missing match does not automatically mean marketing attribution is wrong. Check dates, seller IDs, and the period covered by the data first.

## 2. Agree on what “activated” means

A closed deal and an active seller are not necessarily the same thing. One practical definition is that a seller is activated when their first valid marketplace order is recorded.

Report activation within 30, 60, and 90 days of deal closure. Keep deal-month groups separate so recent deals are not judged by the same time window as older deals.

**Track:** the share activated in each time window and the days between deal closure and first order.

## 3. Keep seller IDs consistent

Check how seller IDs are stored in marketing and marketplace records. If a legitimate ID mapping is needed, keep it in a small documented table. Do not silently guess matches.

**Track:** unmatched IDs and cases with a confirmed explanation.

## 4. Review marketplace activity each month

Use a simple monthly report with delivered orders, distinct customers, item GMV, freight value, average order value, and review scores. Keep the date range and calculation rules consistent.

Item GMV is the sum of item prices. It excludes freight and is not profit.

**Track:** monthly changes and unusual movements that need investigation.

## 5. Keep the data checks

The project found a CSV loading issue that caused the review table to load one row short. Check row counts and loading warnings each time the data is reloaded.

Before using the analysis, check:

- Source and database row counts
- Required IDs
- Duplicate IDs
- Links between related tables
- Missing category translations
- Loading warnings

**Track:** whether every difference has been explained before the report is shared.

## A simple first-month plan

1. Export the unmatched-deal list.
2. Check seller IDs and relevant dates.
3. Assign a reason to each case where possible.
4. Agree on the seller activation definition.
5. Share the monthly summary with the people responsible for marketing and seller operations.