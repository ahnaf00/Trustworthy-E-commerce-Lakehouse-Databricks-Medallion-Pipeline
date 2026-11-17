# Trustworthy E-commerce Lakehouse (Databricks Medallion Assignment)

Synthetic orders + payments -> Bronze (raw) -> Silver (trusted, audited) -> Gold (4 marts) -> AI/BI, Genie, Power BI, Lakeflow Job.

> **Honesty rule:** items marked **[FILL FROM YOUR WORKSPACE]** must come from your own trial. Do not invent counts, links or screenshots.

## 1. Business context
An e-commerce company receives daily CSVs of orders and payments. Nulls, text in numeric fields, bad dates, inconsistent labels, orphan payments and duplicate keys make reports unreliable. This project keeps the raw evidence, cleans with explicit rules, accounts for every row, and publishes one reproducible revenue number.

## 2. Workspace, provider, trial limitations  **[FILL FROM YOUR WORKSPACE]**
| Item | Value |
|------|-------|
| Workspace URL (no tokens) | |
| Cloud / region | |
| Trial start / expiry / credits at start / now | |
| Sign-up email | own email (masked in screenshots) |
| Serverless notebooks / SQL warehouse / Genie / Git folder available? | |
| Observed restrictions + fallback used | |

**Trial vs Free Edition:** the free *trial* is a full paid-tier workspace with a time-limited credit allowance (about 14 days) and the full feature set (serverless, SQL warehouses, Lakeflow Jobs, AI/BI, Genie, Unity Catalog admin). Free Edition is a permanently free, quota-limited environment with restricted compute and features. This assignment targets the trial. Community Edition is a legacy product without Unity Catalog and is not acceptable.

**Compute choices and credit minimisation:** serverless notebook compute for ETL (starts in seconds, no cluster to forget); one **2X-Small** SQL warehouse with auto-stop 5 min for BI. Run notebooks once end-to-end, no parallel experiments, stop the warehouse after every session, no schedules, check credits daily.

## 3. Setup, naming standard, raw path
`USE CATALOG <catalog>; CREATE SCHEMA ecom_poc; CREATE VOLUME raw_files;` (`notebooks/01_setup.sql`).
Naming: `bronze_*` raw, `silver_*` trusted, `quarantine_*` rejected rows, `duplicate_losers_*` non-winners, `gold_*` marts, `_col` audit columns, `*_vw` views. Raw path: `/Volumes/<catalog>/ecom_poc/raw_files/orders.csv` and `.../transactions.csv`. Git: Databricks Git folder (or local repo pushed), one commit per stage: setup, data, bronze, silver, gold, bi, jobs, cleanup. Repository URL: **[FILL]**.

## 4. Synthetic data (`generator/generate_data.py`)
Seeded (`--seed 20261117`), exactly 1,000,000 data rows per file. Injected anomalies: blank values, text in numeric, negatives, future dates/timestamps, unparseable dates/timestamps, case/whitespace labels, invalid country, duplicate keys with conflicting content, exact duplicate rows, orphan order ids (injected + natural). `dirty_data_report.json` lists type, field, count and fraction, file bytes and SHA-256. **Upload evidence:** exact row counts (`source_inventory`), bytes, path **[FILL]**.

**Why anomalies stay a small, measured fraction:** if most data were bad, no rule could tell good from bad, quarantine would swallow the dataset and analytics would be meaningless. A small known fraction tests every rule, yet leaves a trustworthy majority, and because the counts are measured and seeded we can prove the pipeline caught them all (compare the report with `silver_rule_counts`).

**Why real data, credentials and raw extracts never go into Git:** Git history is permanent and widely copied; secrets and personal data leak irreversibly, CSVs of 1M rows bloat the repo, and raw data must live in governed storage. `.gitignore` excludes `*.csv`, `.env`, tokens and `secrets/`. **Minimum production controls:** secret manager (no secrets in code), least-privilege Unity Catalog grants, encryption at rest/in transit, PII masking or tokenisation, audit logs, pre-commit secret scanning, retention rules, and access reviews.

## 5. Bronze (`notebooks/02_bronze_ingestion.sql`)
All fields STRING (`inferSchema => false`, blanks preserved with a sentinel `nullValue`). **Why malformed data belongs in Bronze:** Bronze is the immutable evidence of what the source sent; rejecting at ingestion would hide problems, make re-processing impossible when rules change, and break row-count parity. Audit fields: `_ingested_at` (when loaded), `_source_file` (which file), `_batch_id` (which load; idempotency key), `_row_id` (unique id of the raw row that survives into every outcome table), `_row_hash` (SHA-256 of the content; detects exact duplicates and changes).
**Idempotency:** `INSERT ... WHERE NOT EXISTS (batch_id already in table)`; re-running the same batch inserts 0 rows. Parity query compares an independently counted source (`source_inventory`, plain-text line count minus header) with Bronze: **[FILL: PASS output]**.

## 6. Silver (`notebooks/03_silver_quality.sql`, `sql/01_rules_matrix.sql`)
* **Safe parsing:** `try_cast`; text that cannot be parsed becomes NULL, which the rule matrix then flags (`invalid_*_type`), so the row is quarantined rather than crashing the job or being silently lost.
* **Rule matrix:** valid ranges, mandatory fields, allowed statuses/categories/countries/methods, supported currencies, no future timestamps, orphan and rejected-parent checks (see `sql/01_rules_matrix.sql`).
* **Precedence:** validate first, then deduplicate among valid rows only, so each raw row has one outcome.
* **Deduplication:** key = `order_id` / `txn_id`; keep the row with the smallest `_row_hash` then `_row_id` (deterministic, re-runnable). Losers are kept in `duplicate_losers_*` with `dup_type`: `exact_duplicate_row` (same key and content) vs `conflicting_key_duplicate` (same key, different content).
* **Reconciliation:** `bronze = accepted + quarantined + duplicate losers` per dataset, and no overlap proved by `_row_id` (notebook 05). **[FILL: both PASS outputs, counts by reason, samples]**

## 7. Gold (`notebooks/04_gold_models.sql`)
**Revenue definition:** sum of one accepted payment per eligible order. Eligible order = `completed` or `delivered`. Accepted payment = `txn_status = 'success'` and `currency = 'USD'`; if several, the earliest `txn_ts` (then `txn_id`) wins. Cancelled/pending/returned orders, failed/pending/refunded payments, non-USD payments (no FX conversion), duplicates, orphans, quarantined rows and extra or partial payments are not revenue. Source of truth: `silver_transactions` joined to `silver_orders` in `revenue_base_vw`.
*Worked example:* order O1 completed with payments T1 USD 100 success, T2 USD 100 success (repeat), T3 EUR 90 success. Revenue = 100 (T1 only). Order O2 cancelled with a successful payment = 0. Joining orders to all payments would have given 200+.
Marts (grain / key): `gold_daily_sales` (order_date), `gold_revenue_breakdown` (category,country), `gold_payment_success` (payment_method), `gold_top_customers` (customer_id). Table and column comments and `TBLPROPERTIES(grain, unique_key)` are in the notebook. **Why documentation prevents misreading:** a column named `revenue` without a definition invites someone to sum EUR, include cancelled orders or average a rate; the comment states grain, filters and non-additivity next to the data.

## 8. AI/BI, Genie, Power BI
Dashboard: `dashboards/dashboard_spec.md` (4 counters, trend, 2 breakdowns, shared date filter). Genie: three questions + verification SQL (`sql/05_genie_verification.sql`, `dashboards/genie_checks.md`) or documented restriction. Power BI: `powerbi/` (native connector, **Import** chosen; Import vs DirectQuery explained in `powerbi_instructions.md`; measures in `measures.dax`). Cross-tool revenue table (same dates, USD, same filters): **[FILL]**.

## 9. Lakeflow Job, security, cleanup
Job `operations/lakeflow_job.yml`: bronze_ingestion -> silver_quality -> gold_models -> quality_checks, 2 retries on the first three, failure notifications, no schedule. Gold does not run after a failed dependency by default because it would publish numbers from incomplete or stale Silver data. Least privilege: `sql/02_grants_least_privilege.sql` + `operations/permissions_test_plan.md`. Cleanup: `operations/cleanup_checklist.md`.

## 10. Limitations and fallbacks disclosed **[FILL]**
List every missing feature and the fallback used (e.g. Genie unavailable, Git integration restricted, Power BI exported Gold CSVs).

## 11. Final verification (all must be true in your workspace)
```
source orders rows = bronze_orders rows         source transactions rows = bronze_transactions rows
bronze = accepted silver + quarantined + duplicate losers (each dataset); each _row_id in exactly one outcome
SQL revenue = AI/BI revenue = Power BI revenue  Lakeflow Bronze -> Silver -> Gold -> checks run succeeded
```
`notebooks/05_quality_checks.sql` automates the first two lines and fails the job if anything is not PASS.

Never place tokens, cloud credentials or real personal data in this repository or screenshots.
