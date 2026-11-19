# Power BI Desktop steps

1. **Get Data > Databricks** (native connector). Server hostname and HTTP path: SQL warehouse > *Connection details*. Sign in with Azure AD / OAuth or a personal access token. **Never screenshot or commit the token.**
2. Pick catalog `workspace` > schema `ecom_poc` > the four `gold_*` tables (plus `revenue_base_vw` only if you want a date-aware category chart).
3. **Mode:** choose **Import** (data is copied into the .pbix, charts are fast, the warehouse can stop; data goes stale until Refresh). **DirectQuery** sends every click to the warehouse (always fresh, but slower, keeps the warehouse running = credits, and restricts some DAX). With ~365 daily rows plus small marts, Import is the right choice here.
4. Add the measures from `measures.dax`.
5. One report page: 4 KPI cards (Total Revenue, Revenue Orders, Average Order Value, Cancellation Rate), a line chart (order_date x Total Revenue), a column chart (category x revenue), and slicers (order_date range; optional country/payment_method).
6. Set the slicer to 2026-01-01..2026-12-31, read the **Total Revenue** card, record it below.
7. Save `powerbi/ecom_lakehouse.pbix` and a screenshot `powerbi/report.png`. Check the pbix does not store credentials.

**Fallback if the connector is blocked:** run `SELECT * FROM gold_*` in the SQL editor, download CSVs (Gold only, small), import them into Power BI and write "Gold-only CSV fallback used because <reason>" in the README.

## Completion checklist (tick only when really done)
- [ ] Warehouse running; copied Server hostname + HTTP path (see `gold_import.pq`)
- [ ] Imported the 4 `gold_*` tables (Import mode); screenshot Connection dialog with host masked -> `evidence/23_powerbi_connection.png`
- [ ] Added the 5 measures from `measures.dax`; set `revenue`/`total_spend` to Fixed decimal
- [ ] Built the one-page report (4 cards, line trend, category column chart, date + country/payment slicers) -> `powerbi/report.png` and `evidence/24_powerbi_report.png`
- [ ] Date slicer 2026-01-01..2026-12-31; read **Total Revenue** card and **Revenue Orders**
- [ ] Ran query (1) in `sql/03_cross_tool_validation.sql` in the SQL editor; screenshot -> `evidence/25_revenue_comparison.png` with the dashboard KPI and the Power BI card side by side
- [ ] Saved `powerbi/ecom_lakehouse.pbix` (File > Options > Data source settings: no stored token in the file; delete the PAT afterwards)
- [ ] Filled the table below and README §8

Reference only: the dashboard screenshot (`evidence/dashboard_data.png`) shows Total Revenue about $10.5M, Revenue Orders 23.18K, AOV $451.69, Cancellation 19.98%. These are rounded display values; use the exact SQL figure in the table, not these.

## Revenue comparison (fill from your own outputs)

| Tool | Filters | Total revenue | Orders |
|------|---------|---------------|--------|
| Databricks SQL | 2026-01-01..2026-12-31, USD | | |
| AI/BI dashboard | same | | |
| Power BI | same | | |
| Difference | | | |

Explain any non-zero difference using the checklist in `sql/03_cross_tool_validation.sql`.
