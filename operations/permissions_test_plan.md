# Least-privilege test plan (Gold only)

Grants: `sql/02_grants_least_privilege.sql`.

1. Create (or reuse) a group/user `ecom_reporting`. If account administration is restricted in the trial, record the restriction and keep the grants as the executable plan.
2. Run the grants as owner. Run `SHOW GRANTS ON SCHEMA workspace.ecom_poc;` and screenshot it.
3. As the reporting principal (second browser profile or a test user):
   * `SELECT * FROM gold_daily_sales LIMIT 5;` -> succeeds.
   * `SELECT * FROM silver_orders LIMIT 5;` -> **must fail** (`PERMISSION_DENIED` / insufficient privileges).
   * `SELECT * FROM bronze_orders LIMIT 5;` -> must fail. `LIST '/Volumes/.../raw_files/'` -> must fail.
4. Save the screenshots in `evidence/` as `permissions_allowed.png` and `permissions_denied.png`.
5. If you could not impersonate, say so and show the `SHOW GRANTS` output only.
