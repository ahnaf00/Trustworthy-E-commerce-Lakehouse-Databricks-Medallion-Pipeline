# AI/BI dashboard specification

Build in the workspace: **Dashboards > Create dashboard**. Data = datasets from `sql/04_dashboard_datasets.sql`
(replace `YOUR_CATALOG` first). Use the small SQL warehouse; stop it when finished.

| # | Widget | Type | Dataset | Field / setting |
|---|--------|------|---------|-----------------|
| 1 | Total revenue (USD) | Counter | A | `SUM(total_revenue)` |
| 2 | Revenue orders | Counter | A | `SUM(revenue_orders)` |
| 3 | Average order value | Counter | A | `SUM(total_revenue)/SUM(revenue_orders)` |
| 4 | Cancellation rate | Counter | B (`gold_daily_sales`) | `SUM(cancelled_orders)/SUM(total_orders)` — add these two columns to dataset B |
| 5 | Revenue trend | Line | B | x = `order_date`, y = `revenue` |
| 6 | Revenue by category | Bar | C | x = `category`, y = `SUM(revenue)` |
| 7 | Revenue by country | Bar | C | x = `country`, y = `SUM(revenue)` |
| 8 | Shared filter | Date range filter | A, B, C | field `order_date`; set default 2026-01-01 … 2026-12-31 |

Notes (plain language):
* A **counter** is a big single number. Four counters = the four KPIs the assignment asks for.
* The **shared filter** is one control that changes every chart at once; it must be bound to `order_date` on all datasets, which is why dataset C is built from `revenue_base_vw` (it has a date; `gold_revenue_breakdown` does not).
* Averages of ratios are wrong; always divide a sum by a sum.

Evidence to save in this folder: `dashboard_screenshot.png`, the shared link (**Share > Add link**; if sharing is restricted, **File > Export** and note it), and `genie_checks.md`.

Fill after you run (do not invent values):

| Check | Value |
|-------|-------|
| Dashboard link | |
| Total revenue KPI (filter 2026-01-01..2026-12-31) | |
