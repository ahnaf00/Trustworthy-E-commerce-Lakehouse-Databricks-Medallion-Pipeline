-- Dataset queries for the Databricks AI/BI dashboard (create each as a dataset on Gold tables).
-- Shared filter: a date-range filter on order_date applied to datasets A, B, C, D.
-- Replace workspace first.

-- A. KPI datasets (4 counters). One dataset, four counters:
SELECT SUM(revenue)                                   AS total_revenue,
       SUM(revenue_orders)                            AS revenue_orders,
       SUM(revenue) / NULLIF(SUM(revenue_orders), 0)  AS avg_order_value,
       SUM(cancelled_orders) / NULLIF(SUM(total_orders), 0) AS cancellation_rate,
       order_date
FROM workspace.ecom_poc.gold_daily_sales
GROUP BY order_date;
-- Counter 1 total_revenue = SUM(total_revenue); 2 revenue_orders = SUM; 3 avg_order_value:
-- build it as SUM(total_revenue)/SUM(revenue_orders) (a ratio of sums, not an average of averages);
-- 4 cancellation_rate: use the gold_daily_sales dataset below so the ratio is recomputed from sums.

-- B. Time trend (line chart: x=order_date, y=revenue)
SELECT order_date, revenue, cancellation_rate FROM workspace.ecom_poc.gold_daily_sales;

-- C. Breakdown 1 (bar): revenue by category.  Breakdown 2 (bar): revenue by country.
-- gold_revenue_breakdown has no date column, so for the shared date filter to affect these
-- visuals, use this dataset built from the controlled grain instead:
SELECT order_date, category, country, SUM(revenue_amount) AS revenue
FROM workspace.ecom_poc.revenue_base_vw
GROUP BY order_date, category, country;

-- D. Payment success by method (optional third breakdown)
SELECT payment_method, success_rate, attempted_transactions
FROM workspace.ecom_poc.gold_payment_success;

-- E. Top 10 customers (optional table)
SELECT customer_id, total_spend, spend_rank
FROM workspace.ecom_poc.gold_top_customers WHERE spend_rank <= 10 ORDER BY spend_rank;
