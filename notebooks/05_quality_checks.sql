-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 05 Quality checks (acceptance tests)
-- MAGIC Every check returns PASS/FAIL. The LAST cell raises an error if anything failed, so the Lakeflow task (and the whole job) fails loudly.

-- COMMAND ----------

USE CATALOG workspace;
USE SCHEMA ecom_poc;

-- COMMAND ----------

CREATE OR REPLACE TABLE quality_check_results
COMMENT 'Latest acceptance-check results. status must be PASS for every row.'
AS
-- 1-2 Source -> Bronze parity (source count measured independently in notebook 01)
SELECT 'orders_source_equals_bronze' AS check_name,
  CAST(s.source_data_rows AS STRING) AS expected, CAST(b.n AS STRING) AS actual,
  CASE WHEN s.source_data_rows = b.n THEN 'PASS' ELSE 'FAIL' END AS status
FROM source_inventory s, (SELECT COUNT(*) AS n FROM bronze_orders) b WHERE s.dataset = 'orders'
UNION ALL
SELECT 'transactions_source_equals_bronze', CAST(s.source_data_rows AS STRING), CAST(b.n AS STRING),
  CASE WHEN s.source_data_rows = b.n THEN 'PASS' ELSE 'FAIL' END
FROM source_inventory s, (SELECT COUNT(*) AS n FROM bronze_transactions) b WHERE s.dataset = 'transactions'
UNION ALL
-- 3-4 Exactly 1,000,000 rows (assignment contract)
SELECT 'orders_exactly_1m', '1000000', CAST(source_data_rows AS STRING),
  CASE WHEN source_data_rows = 1000000 THEN 'PASS' ELSE 'FAIL' END FROM source_inventory WHERE dataset = 'orders'
UNION ALL
SELECT 'transactions_exactly_1m', '1000000', CAST(source_data_rows AS STRING),
  CASE WHEN source_data_rows = 1000000 THEN 'PASS' ELSE 'FAIL' END FROM source_inventory WHERE dataset = 'transactions'
UNION ALL
-- 5-6 Outcome equation: bronze = accepted + quarantined + duplicate losers
SELECT concat(dataset, '_outcome_equation'), CAST(bronze_rows AS STRING),
  CAST(accepted_silver + quarantined + duplicate_losers AS STRING),
  CASE WHEN bronze_rows = accepted_silver + quarantined + duplicate_losers THEN 'PASS' ELSE 'FAIL' END
FROM silver_reconciliation
UNION ALL
-- 7-8 No overlap and nothing missing: every raw _row_id appears in exactly one outcome
SELECT 'orders_no_overlap_no_gap', '0 bad ids',
  CAST((SELECT COUNT(*) FROM (SELECT _row_id FROM silver_row_outcomes WHERE dataset = 'orders'
                              GROUP BY _row_id HAVING COUNT(*) <> 1))
     + (SELECT COUNT(*) FROM bronze_orders b WHERE NOT EXISTS
          (SELECT 1 FROM silver_row_outcomes o WHERE o.dataset = 'orders' AND o._row_id = b._row_id)) AS STRING) || ' bad ids',
  CASE WHEN (SELECT COUNT(*) FROM (SELECT _row_id FROM silver_row_outcomes WHERE dataset = 'orders'
                                   GROUP BY _row_id HAVING COUNT(*) <> 1))
          + (SELECT COUNT(*) FROM bronze_orders b WHERE NOT EXISTS
               (SELECT 1 FROM silver_row_outcomes o WHERE o.dataset = 'orders' AND o._row_id = b._row_id)) = 0
       THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'transactions_no_overlap_no_gap', '0 bad ids',
  CAST((SELECT COUNT(*) FROM (SELECT _row_id FROM silver_row_outcomes WHERE dataset = 'transactions'
                              GROUP BY _row_id HAVING COUNT(*) <> 1))
     + (SELECT COUNT(*) FROM bronze_transactions b WHERE NOT EXISTS
          (SELECT 1 FROM silver_row_outcomes o WHERE o.dataset = 'transactions' AND o._row_id = b._row_id)) AS STRING) || ' bad ids',
  CASE WHEN (SELECT COUNT(*) FROM (SELECT _row_id FROM silver_row_outcomes WHERE dataset = 'transactions'
                                   GROUP BY _row_id HAVING COUNT(*) <> 1))
          + (SELECT COUNT(*) FROM bronze_transactions b WHERE NOT EXISTS
               (SELECT 1 FROM silver_row_outcomes o WHERE o.dataset = 'transactions' AND o._row_id = b._row_id)) = 0
       THEN 'PASS' ELSE 'FAIL' END
UNION ALL
-- 9-10 Business keys unique in Silver
SELECT 'silver_orders_key_unique', '0 duplicates', CAST(COUNT(*) - COUNT(DISTINCT order_id) AS STRING) || ' duplicates',
  CASE WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS' ELSE 'FAIL' END FROM silver_orders
UNION ALL
SELECT 'silver_transactions_key_unique', '0 duplicates', CAST(COUNT(*) - COUNT(DISTINCT txn_id) AS STRING) || ' duplicates',
  CASE WHEN COUNT(*) = COUNT(DISTINCT txn_id) THEN 'PASS' ELSE 'FAIL' END FROM silver_transactions
UNION ALL
-- 11 No orphans left in Silver
SELECT 'silver_transactions_no_orphans', '0 orphans', CAST(COUNT(*) AS STRING) || ' orphans',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM silver_transactions t WHERE NOT EXISTS (SELECT 1 FROM silver_orders o WHERE o.order_id = t.order_id)
UNION ALL
-- 12-14 Gold grain keys unique
SELECT 'gold_daily_sales_key_unique', '0 duplicates', CAST(COUNT(*) - COUNT(DISTINCT order_date) AS STRING) || ' duplicates',
  CASE WHEN COUNT(*) = COUNT(DISTINCT order_date) THEN 'PASS' ELSE 'FAIL' END FROM gold_daily_sales
UNION ALL
SELECT 'gold_revenue_breakdown_key_unique', '0 duplicates',
  CAST(COUNT(*) - COUNT(DISTINCT concat(category, '|', country)) AS STRING) || ' duplicates',
  CASE WHEN COUNT(*) = COUNT(DISTINCT concat(category, '|', country)) THEN 'PASS' ELSE 'FAIL' END FROM gold_revenue_breakdown
UNION ALL
SELECT 'gold_top_customers_key_unique', '0 duplicates', CAST(COUNT(*) - COUNT(DISTINCT customer_id) AS STRING) || ' duplicates',
  CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'PASS' ELSE 'FAIL' END FROM gold_top_customers
UNION ALL
-- 15-17 Revenue is identical in every Gold table and in an independently written query
SELECT 'revenue_daily_equals_breakdown', CAST(a.v AS STRING), CAST(b.v AS STRING),
  CASE WHEN a.v = b.v THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(revenue) AS v FROM gold_daily_sales) a, (SELECT SUM(revenue) AS v FROM gold_revenue_breakdown) b
UNION ALL
SELECT 'revenue_daily_equals_top_customers', CAST(a.v AS STRING), CAST(b.v AS STRING),
  CASE WHEN a.v = b.v THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(revenue) AS v FROM gold_daily_sales) a, (SELECT SUM(total_spend) AS v FROM gold_top_customers) b
UNION ALL
SELECT 'revenue_gold_equals_independent_query', CAST(a.v AS STRING), CAST(b.v AS STRING),
  CASE WHEN a.v = b.v THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(revenue) AS v FROM gold_daily_sales) a,
     (SELECT SUM(t.amount) AS v FROM
        (SELECT * FROM silver_transactions WHERE txn_status = 'success' AND currency = 'USD'
         QUALIFY row_number() OVER (PARTITION BY order_id ORDER BY txn_ts, txn_id) = 1) t
        JOIN silver_orders o ON o.order_id = t.order_id
        WHERE o.order_status IN ('completed', 'delivered')) b
UNION ALL
-- 18 Cancellation rate is really measured (guards against the all-zero bug)
SELECT 'cancellation_rate_not_all_zero', '> 0 cancelled orders', CAST(SUM(cancelled_orders) AS STRING),
  CASE WHEN SUM(cancelled_orders) > 0 THEN 'PASS' ELSE 'FAIL' END FROM gold_daily_sales;

SELECT * FROM quality_check_results ORDER BY status DESC, check_name;

-- COMMAND ----------

-- Hard gate: fail the task (and the job) if any check is not PASS.
SELECT assert_true(
  (SELECT COUNT(*) FROM quality_check_results WHERE status <> 'PASS') = 0,
  'quality_check_results contains FAIL rows - see notebook 05 output');
