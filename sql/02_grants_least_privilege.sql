-- Least-privilege reporting access: Gold only.
-- Run as the catalog/schema owner. If creating groups/users is restricted in the trial,
-- keep this file as the "executable grant plan" and test with the plan in operations/.
-- Replace workspace (python tools/set_catalog.py <name>) and PRINCIPAL.

-- CREATE GROUP IF NOT EXISTS ecom_reporting;   -- account-level; may be restricted
GRANT USE CATALOG ON CATALOG workspace TO `ecom_reporting`;
GRANT USE SCHEMA  ON SCHEMA  workspace.ecom_poc TO `ecom_reporting`;
GRANT SELECT ON TABLE workspace.ecom_poc.gold_daily_sales        TO `ecom_reporting`;
GRANT SELECT ON TABLE workspace.ecom_poc.gold_revenue_breakdown  TO `ecom_reporting`;
GRANT SELECT ON TABLE workspace.ecom_poc.gold_payment_success    TO `ecom_reporting`;
GRANT SELECT ON TABLE workspace.ecom_poc.gold_top_customers      TO `ecom_reporting`;
-- Deliberately NOT granted: bronze_*, silver_*, quarantine_*, duplicate_losers_*,
-- silver_stg_*, source_inventory, revenue_base_vw, and any access to volume raw_files.
-- (Reporting users also need CAN USE on the SQL warehouse - set in the warehouse Permissions dialog.)

-- ===== HOW TO TEST (as the reporting principal, or via SHOW GRANTS if you cannot impersonate) =====
SHOW GRANTS ON TABLE workspace.ecom_poc.gold_daily_sales;
SHOW GRANTS ON SCHEMA workspace.ecom_poc;
-- As the reporting user these must SUCCEED:
--   SELECT * FROM workspace.ecom_poc.gold_daily_sales LIMIT 5;
-- and these must FAIL with a permission error (that failure is the evidence):
--   SELECT * FROM workspace.ecom_poc.silver_orders LIMIT 5;
--   SELECT * FROM workspace.ecom_poc.bronze_orders LIMIT 5;
--   LIST '/Volumes/workspace/ecom_poc/raw_files/';
