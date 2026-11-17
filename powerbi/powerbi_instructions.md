# Power BI Desktop steps

1. **Get Data > Databricks** (native connector). Server hostname and HTTP path: SQL warehouse > *Connection details*. Sign in with Azure AD / OAuth or a personal access token. **Never screenshot or commit the token.**
2. Pick catalog `YOUR_CATALOG` > schema `ecom_poc` > the four `gold_*` tables (plus `revenue_base_vw` only if you want a date-aware category chart).
3. **Mode:** choose **Import** (data is copied into the .pbix, charts are fast, the warehouse can stop; data goes stale until Refresh). **DirectQuery** sends every click to the warehouse (always fresh, but slower, keeps the warehouse running = credits, and restricts some DAX). With ~365 daily rows plus small marts, Import is the right choice here.
4. Add the measures from `measures.dax`.
5. One report page: 4 KPI cards (Total Revenue, Revenue Orders, Average Order Value, Cancellation Rate), a line chart (order_date x Total Revenue), a column chart (category x revenue), and slicers (order_date range; optional country/payment_method).
6. Set the slicer to 2026-01-01..2026-12-31, read the **Total Revenue** card, record it below.
7. Save `powerbi/ecom_lakehouse.pbix` and a screenshot `powerbi/report.png`. Check the pbix does not store credentials.

**Fallback if the connector is blocked:** run `SELECT * FROM gold_*` in the SQL editor, download CSVs (Gold only, small), import them into Power BI and write "Gold-only CSV fallback used because <reason>" in the README.

## Revenue comparison (fill from your own outputs)

| Tool | Filters | Total revenue | Orders |
|------|---------|---------------|--------|
| Databricks SQL | 2026-01-01..2026-12-31, USD | | |
| AI/BI dashboard | same | | |
| Power BI | same | | |
| Difference | | | |

Explain any non-zero difference using the checklist in `sql/03_cross_tool_validation.sql`.
