-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 01 Setup - governance objects
-- MAGIC Creates the schema `ecom_poc` and the managed volume `raw_files` inside an existing Unity Catalog catalog.
-- MAGIC **Before running:** replace `YOUR_CATALOG` (find/replace, or `python tools/set_catalog.py <name>`).
-- MAGIC Naming standard: `bronze_*` raw copies, `silver_*` trusted, `quarantine_*` rejected, `duplicate_losers_*` non-winning keys, `gold_*` marts, `_` prefix = audit columns.

-- COMMAND ----------

USE CATALOG YOUR_CATALOG;
CREATE SCHEMA IF NOT EXISTS ecom_poc
  COMMENT 'E-commerce medallion assessment: governed Bronze, Silver and Gold objects (synthetic data only).';
USE SCHEMA ecom_poc;
CREATE VOLUME IF NOT EXISTS raw_files
  COMMENT 'Landing zone for orders.csv and transactions.csv (never committed to Git).';

-- COMMAND ----------

-- Exact raw-file path used everywhere in this project:
--   /Volumes/YOUR_CATALOG/ecom_poc/raw_files/orders.csv
--   /Volumes/YOUR_CATALOG/ecom_poc/raw_files/transactions.csv
-- Upload via UI: New > Add or upload data > Upload files to a volume.
-- Check the files arrived:
LIST '/Volumes/YOUR_CATALOG/ecom_poc/raw_files/';

-- COMMAND ----------

-- Source inventory: independent count of DATA rows (all lines minus the header),
-- byte size and path of each uploaded file. Read as plain TEXT lines so this count
-- does not depend on the CSV parser used for Bronze (important for a fair comparison).
-- Valid because the synthetic files contain no embedded line breaks.
CREATE OR REPLACE TABLE source_inventory
COMMENT 'One row per uploaded source file: path, bytes, data-row count (header excluded). Used by quality checks.'
AS
SELECT 'orders' AS dataset,
       _metadata.file_path AS volume_path,
       max(_metadata.file_size) AS file_bytes,
       count(*) - 1 AS source_data_rows,
       current_timestamp() AS inventoried_at
FROM read_files('/Volumes/YOUR_CATALOG/ecom_poc/raw_files/orders.csv', format => 'text')
GROUP BY _metadata.file_path
UNION ALL
SELECT 'transactions', _metadata.file_path, max(_metadata.file_size), count(*) - 1, current_timestamp()
FROM read_files('/Volumes/YOUR_CATALOG/ecom_poc/raw_files/transactions.csv', format => 'text')
GROUP BY _metadata.file_path;

SELECT * FROM source_inventory;
