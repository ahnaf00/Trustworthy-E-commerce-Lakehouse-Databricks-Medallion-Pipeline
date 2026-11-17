-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 04 Gold - business-ready marts
-- MAGIC **Revenue definition (single source of truth = `revenue_base_vw`, built from `silver_transactions` joined to `silver_orders`):**
-- MAGIC Revenue = sum of ONE accepted payment per eligible order. Eligible order: `order_status` in (`completed`,`delivered`).
-- MAGIC Accepted payment: `txn_status = 'success'` AND `currency = 'USD'`; if an order has several, the earliest by `txn_ts` then `txn_id` wins.
-- MAGIC Not revenue: cancelled/pending/returned orders, failed/pending/refunded payments, non-USD payments (no FX conversion is done), duplicate/orphan/quarantined rows, extra payments on the same order.
-- MAGIC Joining many transactions to one order would multiply order values, so we reduce to one payment per order BEFORE joining.

-- COMMAND ----------

USE CATALOG YOUR_CATALOG;
USE SCHEMA ecom_poc;

-- COMMAND ----------

-- Controlled grain: exactly one row per revenue-eligible order.
CREATE OR REPLACE VIEW revenue_base_vw
COMMENT 'One row per revenue-eligible order (completed/delivered + one successful USD payment). Source of truth for all Gold revenue.'
AS
WITH payment_winner AS (
  SELECT order_id, txn_id, amount, txn_ts
  FROM silver_transactions
  WHERE txn_status = 'success' AND currency = 'USD'
  QUALIFY row_number() OVER (PARTITION BY order_id ORDER BY txn_ts, txn_id) = 1
)
SELECT o.order_id, o.customer_id, o.order_date, o.category, o.country, o.order_status,
       p.txn_id, p.amount AS revenue_amount
FROM silver_orders o
JOIN payment_winner p ON p.order_id = o.order_id
WHERE o.order_status IN ('completed', 'delivered');

-- COMMAND ----------

-- GOLD 1: daily sales + cancellation rate.
-- Cancellation rate is measured on ALL accepted orders of the day (not only revenue orders),
-- otherwise it would always be 0 because cancelled orders are never revenue.
CREATE OR REPLACE TABLE gold_daily_sales AS
WITH day_orders AS (
  SELECT order_date,
         COUNT(*) AS total_orders,
         SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders
  FROM silver_orders GROUP BY order_date
), day_revenue AS (
  SELECT order_date, SUM(revenue_amount) AS revenue, COUNT(*) AS revenue_orders
  FROM revenue_base_vw GROUP BY order_date
)
SELECT d.order_date,
       COALESCE(r.revenue, CAST(0 AS DECIMAL(18,2))) AS revenue,
       COALESCE(r.revenue_orders, 0)                  AS revenue_orders,
       d.total_orders, d.cancelled_orders,
       CAST(d.cancelled_orders AS DOUBLE) / NULLIF(d.total_orders, 0) AS cancellation_rate
FROM day_orders d LEFT JOIN day_revenue r ON r.order_date = d.order_date;

-- GOLD 2: revenue by category and country
CREATE OR REPLACE TABLE gold_revenue_breakdown AS
SELECT category, country, SUM(revenue_amount) AS revenue, COUNT(*) AS revenue_orders
FROM revenue_base_vw GROUP BY category, country;

-- GOLD 3: payment success by method (all accepted Silver transactions, any currency)
CREATE OR REPLACE TABLE gold_payment_success AS
SELECT payment_method,
       COUNT(*) AS attempted_transactions,
       SUM(CASE WHEN txn_status = 'success'  THEN 1 ELSE 0 END) AS successful_transactions,
       SUM(CASE WHEN txn_status = 'failed'   THEN 1 ELSE 0 END) AS failed_transactions,
       SUM(CASE WHEN txn_status = 'refunded' THEN 1 ELSE 0 END) AS refunded_transactions,
       SUM(CASE WHEN txn_status = 'pending'  THEN 1 ELSE 0 END) AS pending_transactions,
       CAST(SUM(CASE WHEN txn_status = 'success' THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(COUNT(*), 0) AS success_rate
FROM silver_transactions GROUP BY payment_method;

-- GOLD 4: customers ranked by spend (rank 1 = highest spender; filter rank <= N for "top N")
CREATE OR REPLACE TABLE gold_top_customers AS
SELECT customer_id, total_spend, revenue_orders,
       row_number() OVER (ORDER BY total_spend DESC, customer_id) AS spend_rank
FROM (SELECT customer_id, SUM(revenue_amount) AS total_spend, COUNT(*) AS revenue_orders
      FROM revenue_base_vw GROUP BY customer_id);

-- COMMAND ----------

-- DOCUMENTATION: table comments, grain, unique key, column comments.
COMMENT ON TABLE gold_daily_sales IS
'Grain: one row per order_date. Unique key: order_date. revenue = USD successful payment winner of completed/delivered orders (revenue_base_vw). cancellation_rate = cancelled_orders / total_orders (all accepted orders that day). Not additive across days: recompute the ratio from sums.';
COMMENT ON TABLE gold_revenue_breakdown IS
'Grain: one row per (category, country). Unique key: category + country. Same revenue definition as gold_daily_sales; totals match.';
COMMENT ON TABLE gold_payment_success IS
'Grain: one row per payment_method. Unique key: payment_method. Counts ALL accepted Silver transactions (any currency/status); success_rate = successful / attempted. This is NOT revenue.';
COMMENT ON TABLE gold_top_customers IS
'Grain: one row per customer_id that has revenue. Unique key: customer_id. total_spend uses the revenue definition; spend_rank 1 = highest.';

ALTER TABLE gold_daily_sales ALTER COLUMN order_date COMMENT 'Order date (UTC calendar day of the order).';
ALTER TABLE gold_daily_sales ALTER COLUMN revenue COMMENT 'Sum of USD successful payment amounts for eligible orders that day.';
ALTER TABLE gold_daily_sales ALTER COLUMN revenue_orders COMMENT 'Number of revenue-eligible orders (rows contributing to revenue).';
ALTER TABLE gold_daily_sales ALTER COLUMN total_orders COMMENT 'All accepted Silver orders that day, any status.';
ALTER TABLE gold_daily_sales ALTER COLUMN cancelled_orders COMMENT 'Accepted orders with status cancelled that day.';
ALTER TABLE gold_daily_sales ALTER COLUMN cancellation_rate COMMENT 'cancelled_orders / total_orders, 0..1.';

ALTER TABLE gold_revenue_breakdown ALTER COLUMN category COMMENT 'Product category (Title case).';
ALTER TABLE gold_revenue_breakdown ALTER COLUMN country COMMENT 'ISO-2 country code of the order.';
ALTER TABLE gold_revenue_breakdown ALTER COLUMN revenue COMMENT 'Sum of eligible USD revenue for this category and country.';
ALTER TABLE gold_revenue_breakdown ALTER COLUMN revenue_orders COMMENT 'Eligible orders counted in revenue.';

ALTER TABLE gold_payment_success ALTER COLUMN payment_method COMMENT 'card, paypal, bank_transfer or wallet.';
ALTER TABLE gold_payment_success ALTER COLUMN attempted_transactions COMMENT 'All accepted transactions for the method.';
ALTER TABLE gold_payment_success ALTER COLUMN successful_transactions COMMENT 'Transactions with txn_status = success.';
ALTER TABLE gold_payment_success ALTER COLUMN failed_transactions COMMENT 'Transactions with txn_status = failed.';
ALTER TABLE gold_payment_success ALTER COLUMN refunded_transactions COMMENT 'Transactions with txn_status = refunded.';
ALTER TABLE gold_payment_success ALTER COLUMN pending_transactions COMMENT 'Transactions with txn_status = pending.';
ALTER TABLE gold_payment_success ALTER COLUMN success_rate COMMENT 'successful_transactions / attempted_transactions, 0..1.';

ALTER TABLE gold_top_customers ALTER COLUMN customer_id COMMENT 'Synthetic customer identifier.';
ALTER TABLE gold_top_customers ALTER COLUMN total_spend COMMENT 'Sum of eligible USD revenue for the customer.';
ALTER TABLE gold_top_customers ALTER COLUMN revenue_orders COMMENT 'Number of eligible orders for the customer.';
ALTER TABLE gold_top_customers ALTER COLUMN spend_rank COMMENT '1 = highest total_spend; ties broken by customer_id.';

ALTER TABLE gold_daily_sales SET TBLPROPERTIES ('grain' = 'order_date', 'unique_key' = 'order_date');
ALTER TABLE gold_revenue_breakdown SET TBLPROPERTIES ('grain' = 'category,country', 'unique_key' = 'category,country');
ALTER TABLE gold_payment_success SET TBLPROPERTIES ('grain' = 'payment_method', 'unique_key' = 'payment_method');
ALTER TABLE gold_top_customers SET TBLPROPERTIES ('grain' = 'customer_id', 'unique_key' = 'customer_id');

-- COMMAND ----------

-- EVIDENCE: Gold table list, row counts and samples
SELECT 'gold_daily_sales' AS tbl, COUNT(*) AS row_count FROM gold_daily_sales
UNION ALL SELECT 'gold_revenue_breakdown', COUNT(*) FROM gold_revenue_breakdown
UNION ALL SELECT 'gold_payment_success', COUNT(*) FROM gold_payment_success
UNION ALL SELECT 'gold_top_customers', COUNT(*) FROM gold_top_customers;

SELECT * FROM gold_daily_sales ORDER BY order_date LIMIT 5;
SELECT * FROM gold_revenue_breakdown ORDER BY revenue DESC LIMIT 5;
SELECT * FROM gold_payment_success;
SELECT * FROM gold_top_customers ORDER BY spend_rank LIMIT 5;
