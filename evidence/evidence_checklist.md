# Evidence checklist (capture from your REAL workspace; mask email, tokens, secrets)

Save files with these names in `evidence/`. Tick when done.

## Workspace and setup
- [ ] `01_workspace_home.png` workspace home + trial/billing status (credits, expiry)
- [ ] `02_account_notes.md` provider, region, start/expiry, restrictions
- [ ] `03_catalog_explorer.png` catalog > ecom_poc > raw_files volume
- [ ] `04_compute.png` serverless notebook + SQL warehouse config (2X-Small, auto-stop)
- [ ] `05_git_history.png` repo URL + commits per stage

## Data and Bronze
- [ ] `dirty_data_report.json` (from generator)
- [ ] `06_upload.png` both files in the volume with sizes
- [ ] `07_source_inventory.png` output of `SELECT * FROM source_inventory`
- [ ] `08_bronze_schema.png` DESCRIBE showing STRING columns + audit columns
- [ ] `09_bronze_sample.png` sample rows with audit columns
- [ ] `10_bronze_parity.png` source vs Bronze PASS
- [ ] `11_idempotency.png` counts before/after re-running the INSERT cells (unchanged)

## Silver
- [ ] `12_rules_matrix.png` output of `sql/01_rules_matrix.sql`
- [ ] `13_typing_examples.png` before/after conversion
- [ ] `14_rule_counts.png` counts by rejection reason
- [ ] `15_dedup_winner_loser.png` winner + losers incl. dup_type
- [ ] `16_reconciliation.png` both datasets PASS (bronze = accepted + quarantined + dup losers)
- [ ] `17_quarantine_sample.png`

## Gold and BI
- [ ] `18_gold_tables.png` four tables, row counts, samples
- [ ] `19_gold_comments.png` Catalog Explorer comments/grain
- [ ] `20_quality_checks.png` all PASS
- [ ] `21_dashboard.png` + link or export
- [ ] `22_genie.png` or `22_genie_unavailable.png` + SQL results
- [ ] `23_powerbi_connection.png` (masked), `24_powerbi_report.png`, `powerbi/*.pbix`
- [ ] `25_revenue_comparison.png` + filled table in `powerbi/powerbi_instructions.md`

## Operations
- [ ] `26_job_graph.png`, `27_job_run_success.png`, `28_job_settings.png` (retries, notifications)
- [ ] `29_permissions.png` (or grant plan only)
- [ ] `30_credits.png`, `31_warehouse_stopped.png`, `32_no_schedule.png`
