-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 03 Silver - typing, validation, quarantine, deduplication, reconciliation
-- MAGIC **Processing precedence (one rule so every raw row has exactly ONE outcome):**
-- MAGIC 1. Type + normalise every Bronze row with `try_cast` (unparseable text becomes NULL, never an error, never a silent drop).
-- MAGIC 2. Validate. Any failed rule -> row goes to `quarantine_*` with every failed rule in `rejection_reason` (joined by `|`).
-- MAGIC 3. Among rows that PASSED validation only, deduplicate by business key. Winner -> `silver_*`; others -> `duplicate_losers_*`.
-- MAGIC 4. Reconcile: Bronze rows = accepted + quarantined + duplicate losers, with no overlap (proved by `_row_id`).

-- COMMAND ----------

USE CATALOG workspace;
USE SCHEMA ecom_poc;
-- Fixed session time zone so timestamp parsing and "future" checks are reproducible.
SET TIME ZONE 'UTC';

-- COMMAND ----------

-- STEP 1 - safe typing + normalisation (orders)
CREATE OR REPLACE TABLE silver_stg_orders AS
SELECT b.*,
  trim(order_id)                                   AS order_id_c,
  trim(customer_id)                                AS customer_id_c,
  lower(trim(order_status))                        AS status_norm,
  upper(trim(country))                             AS country_norm,
  lower(trim(category))                            AS category_norm,
  try_cast(nullif(trim(quantity), '')   AS INT)            AS quantity_typed,
  try_cast(nullif(trim(unit_price), '') AS DECIMAL(18,2))  AS unit_price_typed,
  try_cast(nullif(trim(order_date), '') AS DATE)           AS order_date_typed
FROM bronze_orders b;

-- STEP 1 - safe typing + normalisation (transactions)
CREATE OR REPLACE TABLE silver_stg_transactions AS
SELECT b.*,
  trim(txn_id)                      AS txn_id_c,
  trim(order_id)                    AS order_id_c,
  lower(trim(payment_method))       AS method_norm,
  upper(trim(currency))             AS currency_norm,
  lower(trim(txn_status))           AS status_norm,
  try_cast(nullif(trim(amount), '') AS DECIMAL(18,2)) AS amount_typed,
  try_cast(nullif(trim(txn_ts), '') AS TIMESTAMP)     AS txn_ts_typed
FROM bronze_transactions b;

-- COMMAND ----------

-- STEP 2 - business-rule matrix (orders). Each failed rule adds one label.
CREATE OR REPLACE TABLE silver_stg_orders_validated AS
SELECT *,
  concat_ws('|',
    CASE WHEN order_id_c IS NULL OR order_id_c = '' THEN 'missing_order_id' END,
    CASE WHEN customer_id_c IS NULL OR customer_id_c = '' THEN 'missing_customer_id' END,
    CASE WHEN quantity IS NULL OR trim(quantity) = '' THEN 'missing_quantity'
         WHEN quantity_typed IS NULL THEN 'invalid_quantity_type' END,
    CASE WHEN quantity_typed IS NOT NULL AND (quantity_typed <= 0 OR quantity_typed > 100)
         THEN 'quantity_out_of_range' END,
    CASE WHEN unit_price IS NULL OR trim(unit_price) = '' THEN 'missing_unit_price'
         WHEN unit_price_typed IS NULL THEN 'invalid_unit_price_type' END,
    CASE WHEN unit_price_typed IS NOT NULL AND (unit_price_typed <= 0 OR unit_price_typed > 100000)
         THEN 'unit_price_out_of_range' END,
    CASE WHEN order_date IS NULL OR trim(order_date) = '' THEN 'missing_order_date'
         WHEN order_date_typed IS NULL THEN 'invalid_order_date' END,
    CASE WHEN order_date_typed > current_date() THEN 'future_order_date' END,
    CASE WHEN coalesce(category_norm NOT IN ('electronics','home','beauty','sports','books','grocery'), true)
         THEN 'invalid_category' END,
    CASE WHEN coalesce(status_norm NOT IN ('completed','delivered','cancelled','pending','returned'), true)
         THEN 'invalid_order_status' END,
    CASE WHEN coalesce(country_norm NOT IN ('US','GB','CA','AU','DE','FR','SG'), true)
         THEN 'unsupported_country' END
  ) AS rejection_reason
FROM silver_stg_orders;

-- STEP 2 - business-rule matrix (transactions), including the relationship check.
CREATE OR REPLACE TABLE silver_stg_transactions_validated AS
SELECT t.*,
  concat_ws('|',
    CASE WHEN txn_id_c IS NULL OR txn_id_c = '' THEN 'missing_txn_id' END,
    CASE WHEN order_id_c IS NULL OR order_id_c = '' THEN 'missing_order_id' END,
    CASE WHEN amount IS NULL OR trim(amount) = '' THEN 'missing_amount'
         WHEN amount_typed IS NULL THEN 'invalid_amount_type' END,
    CASE WHEN amount_typed IS NOT NULL AND (amount_typed <= 0 OR amount_typed > 1000000)
         THEN 'amount_out_of_range' END,
    CASE WHEN coalesce(currency_norm NOT IN ('USD','EUR','GBP'), true) THEN 'unsupported_currency' END,
    CASE WHEN coalesce(status_norm NOT IN ('success','failed','refunded','pending'), true)
         THEN 'invalid_txn_status' END,
    CASE WHEN coalesce(method_norm NOT IN ('card','paypal','bank_transfer','wallet'), true)
         THEN 'unsupported_payment_method' END,
    CASE WHEN txn_ts IS NULL OR trim(txn_ts) = '' THEN 'missing_txn_ts'
         WHEN txn_ts_typed IS NULL THEN 'invalid_txn_timestamp' END,
    CASE WHEN txn_ts_typed > current_timestamp() THEN 'future_txn_timestamp' END,
    -- relationship check: the order must exist in the source AND have been accepted
    CASE WHEN order_id_c IS NOT NULL AND order_id_c <> '' AND ao.oid IS NULL THEN 'orphan_order_id'
         WHEN ao.oid IS NOT NULL AND vo.oid IS NULL THEN 'parent_order_rejected' END
  ) AS rejection_reason
FROM silver_stg_transactions t
LEFT JOIN (SELECT DISTINCT order_id_c AS oid FROM silver_stg_orders) ao
       ON ao.oid = t.order_id_c
LEFT JOIN (SELECT DISTINCT order_id_c AS oid FROM silver_stg_orders_validated
           WHERE rejection_reason = '') vo
       ON vo.oid = t.order_id_c;

-- COMMAND ----------

-- STEP 2 result - QUARANTINE (original strings kept untouched + why they failed)
CREATE OR REPLACE TABLE quarantine_orders
COMMENT 'Orders rows that failed >=1 validation rule. Original Bronze strings + audit ids + rejection_reason (rules joined by |).'
AS
SELECT order_id, customer_id, order_date, category, quantity, unit_price, order_status, country,
       _ingested_at, _source_file, _batch_id, _row_id, _row_hash,
       rejection_reason, 'quarantined' AS outcome
FROM silver_stg_orders_validated WHERE rejection_reason <> '';

CREATE OR REPLACE TABLE quarantine_transactions
COMMENT 'Transactions rows that failed >=1 validation rule. Original Bronze strings + audit ids + rejection_reason (rules joined by |).'
AS
SELECT txn_id, order_id, payment_method, amount, currency, txn_status, txn_ts,
       _ingested_at, _source_file, _batch_id, _row_id, _row_hash,
       rejection_reason, 'quarantined' AS outcome
FROM silver_stg_transactions_validated WHERE rejection_reason <> '';

-- COMMAND ----------

-- STEP 3 - deterministic de-duplication among VALID rows only.
-- Keep-one rule: for each business key keep the row with the smallest _row_hash, ties by _row_id.
-- Why: it needs no extra business information, gives the same winner on every re-run, and for
-- exact duplicates (same hash = same content) the choice cannot change any Silver value.
-- Two kinds of duplicate are told apart in dup_type:
--   exact_duplicate_row        = same key AND same content (same _row_hash as the winner)
--   conflicting_key_duplicate  = same key but different content
CREATE OR REPLACE TABLE silver_stg_orders_ranked AS
SELECT *,
  row_number() OVER (PARTITION BY order_id_c ORDER BY _row_hash, _row_id) AS rn,
  first_value(_row_hash) OVER (PARTITION BY order_id_c ORDER BY _row_hash, _row_id) AS winner_hash
FROM silver_stg_orders_validated WHERE rejection_reason = '';

CREATE OR REPLACE TABLE silver_stg_transactions_ranked AS
SELECT *,
  row_number() OVER (PARTITION BY txn_id_c ORDER BY _row_hash, _row_id) AS rn,
  first_value(_row_hash) OVER (PARTITION BY txn_id_c ORDER BY _row_hash, _row_id) AS winner_hash
FROM silver_stg_transactions_validated WHERE rejection_reason = '';

CREATE OR REPLACE TABLE duplicate_losers_orders
COMMENT 'Valid order rows that lost the keep-one rule for their order_id. Never deleted, kept for audit.'
AS
SELECT order_id, customer_id, order_date, category, quantity, unit_price, order_status, country,
       _ingested_at, _source_file, _batch_id, _row_id, _row_hash,
       CASE WHEN _row_hash = winner_hash THEN 'exact_duplicate_row' ELSE 'conflicting_key_duplicate' END AS dup_type,
       'duplicate_key_loser' AS outcome
FROM silver_stg_orders_ranked WHERE rn > 1;

CREATE OR REPLACE TABLE duplicate_losers_transactions
COMMENT 'Valid transaction rows that lost the keep-one rule for their txn_id. Never deleted, kept for audit.'
AS
SELECT txn_id, order_id, payment_method, amount, currency, txn_status, txn_ts,
       _ingested_at, _source_file, _batch_id, _row_id, _row_hash,
       CASE WHEN _row_hash = winner_hash THEN 'exact_duplicate_row' ELSE 'conflicting_key_duplicate' END AS dup_type,
       'duplicate_key_loser' AS outcome
FROM silver_stg_transactions_ranked WHERE rn > 1;

-- COMMAND ----------

-- STEP 3 result - TRUSTED, TYPED Silver tables (one row per business key)
CREATE OR REPLACE TABLE silver_orders
COMMENT 'Trusted orders. Grain: one row per order_id. Typed, validated, normalised; one winner per key.'
AS
SELECT order_id_c AS order_id, customer_id_c AS customer_id,
       order_date_typed AS order_date, initcap(category_norm) AS category,
       quantity_typed AS quantity, unit_price_typed AS unit_price,
       status_norm AS order_status, country_norm AS country,
       _ingested_at, _source_file, _batch_id, _row_id, _row_hash
FROM silver_stg_orders_ranked WHERE rn = 1;

CREATE OR REPLACE TABLE silver_transactions
COMMENT 'Trusted payment transactions. Grain: one row per txn_id. Every order_id exists in silver_orders.'
AS
SELECT txn_id_c AS txn_id, order_id_c AS order_id, method_norm AS payment_method,
       amount_typed AS amount, currency_norm AS currency, status_norm AS txn_status,
       txn_ts_typed AS txn_ts,
       _ingested_at, _source_file, _batch_id, _row_id, _row_hash
FROM silver_stg_transactions_ranked WHERE rn = 1;

-- COMMAND ----------

-- STEP 4 - RECONCILIATION: Bronze = accepted + quarantined + duplicate losers
CREATE OR REPLACE TABLE silver_reconciliation
COMMENT 'Row accounting per dataset: bronze_rows must equal accepted + quarantined + duplicate_losers.'
AS
SELECT 'orders' AS dataset,
  (SELECT COUNT(*) FROM bronze_orders)               AS bronze_rows,
  (SELECT COUNT(*) FROM silver_orders)               AS accepted_silver,
  (SELECT COUNT(*) FROM quarantine_orders)           AS quarantined,
  (SELECT COUNT(*) FROM duplicate_losers_orders)     AS duplicate_losers
UNION ALL
SELECT 'transactions',
  (SELECT COUNT(*) FROM bronze_transactions),
  (SELECT COUNT(*) FROM silver_transactions),
  (SELECT COUNT(*) FROM quarantine_transactions),
  (SELECT COUNT(*) FROM duplicate_losers_transactions);

SELECT *, accepted_silver + quarantined + duplicate_losers AS outcome_total,
       CASE WHEN bronze_rows = accepted_silver + quarantined + duplicate_losers
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM silver_reconciliation;

-- COMMAND ----------

-- No-overlap proof: one list of (dataset, _row_id, outcome). If any raw row sat in two buckets,
-- its _row_id would appear twice (checked in notebook 05).
CREATE OR REPLACE VIEW silver_row_outcomes AS
SELECT 'orders' AS dataset, _row_id, 'accepted' AS outcome FROM silver_orders
UNION ALL SELECT 'orders', _row_id, 'quarantined' FROM quarantine_orders
UNION ALL SELECT 'orders', _row_id, 'duplicate_loser' FROM duplicate_losers_orders
UNION ALL SELECT 'transactions', _row_id, 'accepted' FROM silver_transactions
UNION ALL SELECT 'transactions', _row_id, 'quarantined' FROM quarantine_transactions
UNION ALL SELECT 'transactions', _row_id, 'duplicate_loser' FROM duplicate_losers_transactions;

-- COMMAND ----------

-- Counts by rejection reason (a row with 2 failed rules is counted once per rule here)
CREATE OR REPLACE TABLE silver_rule_counts AS
SELECT 'orders' AS dataset, r AS rule, COUNT(*) AS failing_rows
FROM quarantine_orders LATERAL VIEW explode(split(rejection_reason, '\\|')) x AS r GROUP BY r
UNION ALL
SELECT 'transactions', r, COUNT(*)
FROM quarantine_transactions LATERAL VIEW explode(split(rejection_reason, '\\|')) x AS r GROUP BY r;

SELECT * FROM silver_rule_counts ORDER BY dataset, failing_rows DESC;

-- COMMAND ----------

-- EVIDENCE queries (screenshot these)
-- Before/after typing examples: raw STRING vs typed value (NULL = could not be parsed)
SELECT order_id, quantity AS quantity_raw, quantity_typed,
       unit_price AS price_raw, unit_price_typed, order_date AS date_raw, order_date_typed
FROM silver_stg_orders
WHERE quantity_typed IS NULL OR unit_price_typed IS NULL OR order_date_typed IS NULL
LIMIT 10;

-- Sample of quarantined rows (original audit ids preserved)
SELECT * FROM quarantine_orders LIMIT 10;
SELECT * FROM quarantine_transactions LIMIT 10;

-- Winner vs loser for a duplicated key
SELECT 'winner' AS role, order_id, customer_id, order_date, _row_id FROM silver_orders WHERE order_id = 'O00000001'
UNION ALL
SELECT dup_type, order_id, customer_id, order_date, _row_id FROM duplicate_losers_orders WHERE trim(order_id) = 'O00000001';

SELECT dup_type, COUNT(*) AS rows FROM duplicate_losers_orders GROUP BY dup_type;
SELECT dup_type, COUNT(*) AS rows FROM duplicate_losers_transactions GROUP BY dup_type;
