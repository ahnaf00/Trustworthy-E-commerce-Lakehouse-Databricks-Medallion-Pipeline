-- Business-rule matrix. The enforcing logic lives in notebooks/03_silver_quality.sql;
-- this table documents it and lets you JOIN rule descriptions to silver_rule_counts.
USE CATALOG YOUR_CATALOG;
USE SCHEMA ecom_poc;

CREATE OR REPLACE TABLE silver_rules_matrix
COMMENT 'Documentation of every Silver validation rule: dataset, field, rule, rejection label.'
AS SELECT * FROM VALUES
 ('orders','order_id','mandatory (non-blank)','missing_order_id'),
 ('orders','customer_id','mandatory (non-blank)','missing_customer_id'),
 ('orders','quantity','mandatory','missing_quantity'),
 ('orders','quantity','must parse to INT (try_cast)','invalid_quantity_type'),
 ('orders','quantity','1..100','quantity_out_of_range'),
 ('orders','unit_price','mandatory','missing_unit_price'),
 ('orders','unit_price','must parse to DECIMAL(18,2)','invalid_unit_price_type'),
 ('orders','unit_price','>0 and <=100000','unit_price_out_of_range'),
 ('orders','order_date','mandatory','missing_order_date'),
 ('orders','order_date','must parse to DATE','invalid_order_date'),
 ('orders','order_date','not in the future','future_order_date'),
 ('orders','category','one of electronics,home,beauty,sports,books,grocery (case/space-insensitive)','invalid_category'),
 ('orders','order_status','one of completed,delivered,cancelled,pending,returned (normalised)','invalid_order_status'),
 ('orders','country','one of US,GB,CA,AU,DE,FR,SG (normalised)','unsupported_country'),
 ('transactions','txn_id','mandatory (non-blank)','missing_txn_id'),
 ('transactions','order_id','mandatory (non-blank)','missing_order_id'),
 ('transactions','amount','mandatory','missing_amount'),
 ('transactions','amount','must parse to DECIMAL(18,2)','invalid_amount_type'),
 ('transactions','amount','>0 and <=1000000','amount_out_of_range'),
 ('transactions','currency','one of USD,EUR,GBP','unsupported_currency'),
 ('transactions','txn_status','one of success,failed,refunded,pending','invalid_txn_status'),
 ('transactions','payment_method','one of card,paypal,bank_transfer,wallet','unsupported_payment_method'),
 ('transactions','txn_ts','mandatory','missing_txn_ts'),
 ('transactions','txn_ts','must parse to TIMESTAMP','invalid_txn_timestamp'),
 ('transactions','txn_ts','not in the future','future_txn_timestamp'),
 ('transactions','order_id','order must exist in orders source (relationship)','orphan_order_id'),
 ('transactions','order_id','parent order must itself be accepted','parent_order_rejected'),
 ('both','business key','keep one row per key among VALID rows (min _row_hash, then _row_id); rest = duplicate losers','(not a rejection: duplicate_losers_*)')
AS t(dataset, field, rule, outcome_label);

SELECT m.dataset, m.field, m.rule, m.outcome_label, coalesce(c.failing_rows, 0) AS failing_rows
FROM silver_rules_matrix m
LEFT JOIN silver_rule_counts c ON c.dataset = m.dataset AND c.rule = m.outcome_label
ORDER BY m.dataset, m.field;
