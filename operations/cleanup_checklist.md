# Cleanup and trial-expiry checklist (tick only what you really did)

- [ ] Remaining credits checked (Account console > Usage / trial banner). Screenshot saved: `evidence/credits.png`. Value: ______
- [ ] SQL warehouse **stopped** (SQL Warehouses > Stop). Screenshot: `evidence/warehouse_stopped.png`
- [ ] No notebook compute left running (serverless disconnects itself; verify in Compute).
- [ ] Job has **no schedule** / schedule **paused**. Screenshot of Job > Schedules & triggers.
- [ ] Genie space and dashboard sharing set the way you intend (no public/open links with real data - data is synthetic anyway).
- [ ] Notebooks exported (Workspace > Export > Source/DBC) or synced to Git; Git commit pushed. Repo URL: ______
- [ ] Dashboard exported (File > Download as .lvdash.json) or link recorded.
- [ ] `.pbix`, screenshots and evidence copied into this repo; `.gitignore` still excludes CSVs and secrets.
- [ ] Revoke/delete any personal access token created for Power BI.
- [ ] Never added a payment method or upgraded the account.
- [ ] Trial start ______ and expiry ______ recorded; submission before 19 Nov 2026.

## Job behaviour to explain in the README
If `silver_quality` fails (after its 2 retries) the downstream task `gold_models` is marked **Upstream failed** and does not run. This is the default because Gold would otherwise be built from stale or half-written Silver data and publish wrong numbers; a missing report is safer than a wrong one.
