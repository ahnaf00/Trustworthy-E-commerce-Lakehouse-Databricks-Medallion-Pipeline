-- Same revenue, same filters, three tools. Fixed filter used EVERYWHERE:
--   order_date between 2026-01-01 and 2026-12-31, currency USD, eligible orders only.
USE CATALOG workspace;
USE SCHEMA ecom_poc;

-- (1) Databricks SQL warehouse result - run this and screenshot it:
SELECT SUM(revenue)         AS total_revenue,
       SUM(revenue_orders)  AS revenue_orders
FROM gold_daily_sales
WHERE order_date BETWEEN DATE '2026-01-01' AND DATE '2026-12-31';

-- (2) AI/BI dashboard KPI "Total revenue" must use the SAME dataset query + same filter
--     (see dashboards/dashboard_spec.md). Read the KPI counter value.
-- (3) Power BI card [Total Revenue] with the same date slicer range (see powerbi/measures.dax).

-- Source-of-truth cross-check straight from the controlled grain (must equal (1)):
SELECT SUM(revenue_amount) AS total_revenue_from_base, COUNT(*) AS revenue_orders
FROM revenue_base_vw
WHERE order_date BETWEEN DATE '2026-01-01' AND DATE '2026-12-31';

-- Mismatch diagnosis checklist (run the one that applies):
-- a) Rounding: compare ROUND(x, 2); Power BI "Fixed decimal" avoids float drift.
-- b) Date filter: a slicer set to 2026-01-01..2026-12-31 inclusive; check time zones for timestamps.
-- c) Currency: only USD is revenue; no cross-currency sum anywhere.
-- d) Stale Import: Power BI Import shows data as of last Refresh -> press Refresh.
-- e) Wrong table: any measure built from silver_* or from a join to transactions multiplies rows.
SELECT currency, txn_status, COUNT(*) AS rows, SUM(amount) AS amount_sum
FROM silver_transactions GROUP BY currency, txn_status ORDER BY currency, txn_status;
