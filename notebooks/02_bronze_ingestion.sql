-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 02 Bronze - lossless ingestion
-- MAGIC Every source column is stored as STRING (no schema inference, nothing cast, nothing dropped).
-- MAGIC Bad data stays in Bronze on purpose: Bronze is the evidence. Rejecting at the door would destroy the proof of what the source sent.
-- MAGIC
-- MAGIC Audit columns:
-- MAGIC * `_ingested_at` - when this load ran (when did we receive it?)
-- MAGIC * `_source_file` - exact volume path of the file (where did it come from?)
-- MAGIC * `_batch_id` - label of the load; the same batch is never loaded twice (idempotency)
-- MAGIC * `_row_id` - unique id of this Bronze row (`batch-number`); every later outcome table keeps it, so any report number traces back to one raw row
-- MAGIC * `_row_hash` - SHA-256 of all source fields; identical hash = identical content (detects exact duplicates)

-- COMMAND ----------

USE CATALOG YOUR_CATALOG;
USE SCHEMA ecom_poc;

CREATE TABLE IF NOT EXISTS bronze_orders (
  order_id STRING, customer_id STRING, order_date STRING, category STRING,
  quantity STRING, unit_price STRING, order_status STRING, country STRING,
  _ingested_at TIMESTAMP, _source_file STRING, _batch_id STRING, _row_id STRING, _row_hash STRING
) USING DELTA COMMENT 'Raw orders, all source fields STRING, plus audit columns. Append-only per batch.';

CREATE TABLE IF NOT EXISTS bronze_transactions (
  txn_id STRING, order_id STRING, payment_method STRING, amount STRING,
  currency STRING, txn_status STRING, txn_ts STRING,
  _ingested_at TIMESTAMP, _source_file STRING, _batch_id STRING, _row_id STRING, _row_hash STRING
) USING DELTA COMMENT 'Raw transactions, all source fields STRING, plus audit columns. Append-only per batch.';

-- COMMAND ----------

-- One new batch id per source-file version. Re-running the SAME batch id loads nothing.
-- (To load a new file version, change this label, e.g. '20261118_v2'.)
DECLARE OR REPLACE VARIABLE batch_id STRING DEFAULT '20261117_initial';

-- COMMAND ----------

-- nullValue is set to a sentinel that never occurs so that blank cells stay '' (lossless)
-- instead of being silently turned into NULL by the CSV reader.
INSERT INTO bronze_orders
SELECT
  order_id, customer_id, order_date, category, quantity, unit_price, order_status, country,
  current_timestamp(),
  _metadata.file_path,
  batch_id,
  concat(batch_id, '-', lpad(CAST(monotonically_increasing_id() AS STRING), 12, '0')),
  sha2(to_json(named_struct(
    'order_id', order_id, 'customer_id', customer_id, 'order_date', order_date,
    'category', category, 'quantity', quantity, 'unit_price', unit_price,
    'order_status', order_status, 'country', country)), 256)
FROM read_files(
  '/Volumes/YOUR_CATALOG/ecom_poc/raw_files/orders.csv',
  format => 'csv', header => true, inferSchema => false, nullValue => '__NO_NULL__')
WHERE NOT EXISTS (SELECT 1 FROM bronze_orders b WHERE b._batch_id = batch_id);

-- COMMAND ----------

INSERT INTO bronze_transactions
SELECT
  txn_id, order_id, payment_method, amount, currency, txn_status, txn_ts,
  current_timestamp(),
  _metadata.file_path,
  batch_id,
  concat(batch_id, '-', lpad(CAST(monotonically_increasing_id() AS STRING), 12, '0')),
  sha2(to_json(named_struct(
    'txn_id', txn_id, 'order_id', order_id, 'payment_method', payment_method,
    'amount', amount, 'currency', currency, 'txn_status', txn_status, 'txn_ts', txn_ts)), 256)
FROM read_files(
  '/Volumes/YOUR_CATALOG/ecom_poc/raw_files/transactions.csv',
  format => 'csv', header => true, inferSchema => false, nullValue => '__NO_NULL__')
WHERE NOT EXISTS (SELECT 1 FROM bronze_transactions b WHERE b._batch_id = batch_id);

-- COMMAND ----------

-- Evidence: schema proves STRING columns; sample shows audit columns; counts show parity.
DESCRIBE TABLE bronze_orders;
DESCRIBE TABLE bronze_transactions;
SELECT * FROM bronze_orders LIMIT 5;
SELECT * FROM bronze_transactions LIMIT 5;

SELECT s.dataset, s.source_data_rows, b.bronze_rows,
       CASE WHEN s.source_data_rows = b.bronze_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM source_inventory s
JOIN (SELECT 'orders' AS dataset, COUNT(*) AS bronze_rows FROM bronze_orders
      UNION ALL SELECT 'transactions', COUNT(*) FROM bronze_transactions) b
  ON b.dataset = s.dataset;

-- COMMAND ----------

-- Idempotency demo: run the two INSERT cells again. Counts above must not change,
-- because the NOT EXISTS guard finds the batch id already present.
SELECT _batch_id, COUNT(*) AS rows_in_batch FROM bronze_orders GROUP BY _batch_id;
SELECT _batch_id, COUNT(*) AS rows_in_batch FROM bronze_transactions GROUP BY _batch_id;
