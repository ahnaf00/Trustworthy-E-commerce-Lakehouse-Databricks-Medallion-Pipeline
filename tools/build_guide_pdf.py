"""Build the step-by-step guide PDF.  Usage: python tools/build_guide_pdf.py <output.pdf>"""
import sys
from xml.sax.saxutils import escape
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, Frame, PageTemplate, PageBreak, Paragraph,
                                Preformatted, Spacer, Table, TableStyle, KeepTogether)

out = sys.argv[1] if len(sys.argv) > 1 else "guide.pdf"
ss = getSampleStyleSheet()
INK, BLUE, GREY = colors.HexColor("#1b2733"), colors.HexColor("#1f5fbf"), colors.HexColor("#5b6773")
H1 = ParagraphStyle("H1", parent=ss["Heading1"], fontSize=19, textColor=BLUE, spaceBefore=4, spaceAfter=8)
H2 = ParagraphStyle("H2", parent=ss["Heading2"], fontSize=13.5, textColor=INK, spaceBefore=10, spaceAfter=4)
H3 = ParagraphStyle("H3", parent=ss["Heading3"], fontSize=10.5, textColor=BLUE, spaceBefore=6, spaceAfter=2)
B = ParagraphStyle("B", parent=ss["BodyText"], fontSize=9.5, leading=13, textColor=INK)
SM = ParagraphStyle("SM", parent=B, fontSize=8.5, leading=11.5, textColor=GREY)
BUL = ParagraphStyle("BUL", parent=B, leftIndent=12, bulletIndent=2, spaceAfter=1)
CODE = ParagraphStyle("CODE", fontName="Courier", fontSize=7.8, leading=9.6, textColor=INK)

story = []


def h1(t): story.append(Paragraph(escape(t), H1))
def h2(t): story.append(Paragraph(escape(t), H2))
def h3(t): story.append(Paragraph(escape(t), H3))
def p(t): story.append(Paragraph(t, B))
def sm(t): story.append(Paragraph(t, SM))
def bl(items):
    for i in items:
        story.append(Paragraph(i, BUL, bulletText="-"))
def code(t):
    box = Table([[Preformatted(t.strip("\n"), CODE)]], colWidths=[172 * mm])
    box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#f3f5f8")),
                             ("BOX", (0, 0), (-1, -1), 0.4, colors.HexColor("#cfd6de")),
                             ("LEFTPADDING", (0, 0), (-1, -1), 6), ("TOPPADDING", (0, 0), (-1, -1), 4),
                             ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
    story.append(box); story.append(Spacer(1, 4))
def note(t, label="NOTE (in easy words)", bg="#eaf3ff", edge="#1f5fbf"):
    box = Table([[Paragraph("<b>%s</b><br/>%s" % (label, t), B)]], colWidths=[172 * mm])
    box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(bg)),
                             ("LINEBEFORE", (0, 0), (0, -1), 2.5, colors.HexColor(edge)),
                             ("LEFTPADDING", (0, 0), (-1, -1), 8), ("TOPPADDING", (0, 0), (-1, -1), 5),
                             ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
    story.append(KeepTogether([box, Spacer(1, 5)]))
def evidence(t): note(t, "EVIDENCE TO SAVE", "#eefaf0", "#2e8b57")
def warn(t): note(t, "WATCH OUT", "#fff4e5", "#d9822b")
def table(rows, widths, head=True):
    data = [[Paragraph(str(c), SM if i else ParagraphStyle("th", parent=SM, textColor=colors.white, fontName="Helvetica-Bold"))
             for c in r] for i, r in enumerate(rows)]
    t = Table(data, colWidths=[w * mm for w in widths], repeatRows=1)
    st = [("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#cfd6de")), ("VALIGN", (0, 0), (-1, -1), "TOP")]
    if head: st.append(("BACKGROUND", (0, 0), (-1, 0), BLUE))
    t.setStyle(TableStyle(st)); story.append(t); story.append(Spacer(1, 6))


def footer(c, d):
    c.saveState(); c.setFont("Helvetica", 7.5); c.setFillColor(GREY)
    c.drawString(18 * mm, 10 * mm, "Databricks Medallion Assignment - step-by-step guide (instructor: Lipton Ahammed, due 19 Nov 2026)")
    c.drawRightString(192 * mm, 10 * mm, "Page %d" % d.page); c.restoreState()


# ------------------------------------------------------------------ COVER / OVERVIEW
h1("Build a Trustworthy E-commerce Lakehouse")
p("<b>A beginner-friendly, step-by-step guide to finish the Databricks Medallion assignment yourself.</b>")
sm("Every step has: what to do, the exact file/command, a NOTE in easy words, and the EVIDENCE to save.")
story.append(Spacer(1, 6))
warn("<b>Read this first.</b> The assignment must be run in <b>your own Databricks free-trial workspace</b> and graded on "
     "<b>real evidence</b> (screenshots, counts, links, job run). This package gives you finished, ready-to-run code and "
     "documents, but it cannot create your trial, run your workspace, or produce your screenshots. Nothing in the "
     "package contains invented results: every place that needs a number from your workspace says <b>[FILL]</b>. "
     "The SQL was written carefully but was <b>not executed</b> by the author (no workspace available); the Python generator "
     "<i>was</i> executed and produced exactly 1,000,000 data rows per file. If a cell errors in your workspace, "
     "see Troubleshooting (Appendix B).")
h2("Time plan (today is 17 Nov, deadline 19 Nov 2026)")
table([["When", "Do", "Steps"],
       ["Day 1 (17 Nov)", "Account, workspace, Git, generate + upload data, Bronze, Silver, Gold, quality checks", "1-9"],
       ["Day 2 (18 Nov)", "AI/BI dashboard, Genie, Power BI, Lakeflow job, permissions", "10-14"],
       ["Day 3 (19 Nov, morning)", "Cleanup, README fill-in, evidence folder, zip/push, submit", "15-16"]], [38, 112, 22])
sm("If the trial only starts when you sign up, start it ONLY when you are ready to work for several hours (the credit window is about 14 days).")

h2("What is in the package")
table([["Folder / file", "What it is"],
       ["README.md", "The written answers to every assignment question (fill the [FILL] cells)"],
       ["generator/generate_data.py", "Seeded generator: 1,000,000 + 1,000,000 data rows, dirty-data report"],
       ["notebooks/01..05_*.sql", "Setup, Bronze, Silver, Gold, quality checks (Databricks SQL notebooks)"],
       ["sql/", "Rules matrix, least-privilege grants, cross-tool validation, dashboard datasets, Genie SQL"],
       ["dashboards/, powerbi/", "Dashboard spec, Genie checks, DAX measures, Power BI steps"],
       ["operations/", "Lakeflow job (YAML), permissions test plan, cleanup checklist"],
       ["evidence/", "Checklist of every screenshot/output to capture (you add the files)"],
       ["tools/", "set_catalog.py (replace YOUR_CATALOG), build_guide_pdf.py (this PDF)"]], [52, 120])

h2("The big picture in plain words")
p("Imagine a kitchen. <b>Bronze</b> is the delivery box exactly as the supplier sent it (even if some food is spoiled). "
  "<b>Silver</b> is the kitchen counter where each item is checked, cleaned, and the bad ones are put in a labelled "
  "tray (quarantine) instead of the bin. <b>Gold</b> is the finished dish ready for customers (reports). The golden rule: "
  "<b>count everything.</b> Boxes delivered = good + spoiled + duplicates. Nothing disappears.")
table([["Layer", "Tables", "Job"],
       ["Landing", "Volume raw_files: orders.csv, transactions.csv", "Keep original files untouched"],
       ["Bronze", "bronze_orders, bronze_transactions", "All columns as text + audit columns. Lossless"],
       ["Silver", "silver_orders/transactions, quarantine_*, duplicate_losers_*", "Type, validate, dedupe. Every row has one outcome"],
       ["Gold", "gold_daily_sales, gold_revenue_breakdown, gold_payment_success, gold_top_customers", "Documented business numbers"],
       ["Consume", "AI/BI dashboard, Genie, Power BI", "Same revenue number everywhere"],
       ["Operate", "Lakeflow Job, Unity Catalog grants, Git", "Repeatable, secure, cheap"]], [24, 84, 64])
h3("Row-accounting rule (the heart of the project)")
code("""bronze rows  =  accepted silver rows  +  quarantined rows  +  duplicate losers
(each raw row, identified by _row_id, is in exactly ONE of the three buckets)

Order of processing:  1) type + validate -> failed rows go to quarantine
                      2) among VALID rows only, de-duplicate by business key""")
note("Why this order? If you removed duplicates first, a bad copy might win and a good copy would be thrown away. "
     "Validate first, then pick one winner among the good rows. That makes the count add up exactly.")
story.append(PageBreak())

# ------------------------------------------------------------------ STEPS
h1("Step 1 - Create your own Databricks free-trial account")
bl(["Open the official Databricks free trial sign-up. Use <b>your own email</b> (not the instructor's, not shared). Verify the email.",
    "Choose <b>express setup</b> if offered (a managed serverless workspace; no cloud account of yours needed).",
    "You need the <b>free trial</b>, not Community Edition and not Free Edition.",
    "Record: workspace URL, cloud + region, trial start date, expiry, remaining credits, and any feature that is missing."])
note("The trial gives you a limited amount of credit for about 14 days. Everything you run (notebooks, SQL warehouse) spends credit. "
     "That is why this guide tells you to stop compute and never add a payment method.")
warn("Never add a payment method or upgrade. Never paste tokens into notes or screenshots.")
evidence("01_workspace_home.png (home page + trial/billing banner); 02_account_notes.md (provider, region, start/expiry, restrictions). "
         "Then answer in README section 2: how the trial differs from Free Edition (already written for you; check it matches what you see).")

h1("Step 2 - Governance objects (catalog, schema, volume) and Git")
bl(["Open <b>Catalog</b> and pick a catalog where you may create a schema (often your own or <i>main</i>/workspace catalog).",
    "In the package folder run: <font face='Courier'>python tools/set_catalog.py your_catalog_name</font> to replace YOUR_CATALOG everywhere. "
    "(Or use find/replace in each notebook.)",
    "Create a notebook from <font face='Courier'>notebooks/01_setup.sql</font> (import the file) and run the first cells."])
code("""USE CATALOG your_catalog;
CREATE SCHEMA IF NOT EXISTS ecom_poc;
USE SCHEMA ecom_poc;
CREATE VOLUME IF NOT EXISTS raw_files;
-- raw path: /Volumes/your_catalog/ecom_poc/raw_files/""")
note("Unity Catalog is Databricks' organised cupboard: catalog > schema > tables/volumes. A <b>volume</b> is a folder for files "
     "(our CSVs). Names follow a standard: bronze_*, silver_*, gold_*, quarantine_*, duplicate_losers_* so anyone knows what a table is.")
bl(["<b>Git:</b> create an empty repository (GitHub/GitLab). In Databricks: <b>Workspace > Create > Git folder</b>, paste the URL, add credentials. "
    "Copy the package into it and commit after every stage (setup, data, bronze, silver, gold, bi, jobs, cleanup). "
    "If Git folders are blocked, work locally and <font face='Courier'>git push</font>, and write that limitation in the README."])
warn("Do NOT commit the CSV files. The provided .gitignore already blocks *.csv, tokens and secrets.")
evidence("03_catalog_explorer.png (catalog, ecom_poc, raw_files); 05_git_history.png (repo URL + commits). If you cannot create a catalog, "
         "use an existing writable one and say so.")

h1("Step 3 - Choose compute (and keep the bill at zero)")
bl(["ETL notebooks: <b>serverless</b> notebook compute (quick start, auto-stops, nothing to manage).",
    "BI and queries: one <b>2X-Small SQL warehouse</b>, <b>auto-stop 5 minutes</b>, one cluster only.",
    "Do not run experiments in parallel. Stop the warehouse after each session."])
note("Notebooks are for building (batch work); a SQL warehouse is for answering many small queries from dashboards and Power BI. "
     "Using the smallest size and auto-stop means you only pay while something is really running.")
evidence("04_compute.png (serverless + warehouse configuration). Write 2-3 sentences of 'why' in the README (already drafted).")

h1("Step 4 - Generate the synthetic data")
code("""cd final_submission
python generator/generate_data.py --output-dir ./generated --seed 20261117""")
p("It writes <b>orders.csv</b> (about 60 MB), <b>transactions.csv</b> (about 74 MB) and <b>dirty_data_report.json</b> "
  "(runs in roughly a minute; needs only Python 3.9+).")
table([["Dirty data type", "orders", "transactions"],
       ["Blank / null values", "quantity", "amount"],
       ["Text in numeric field", "unit_price = not_available", "amount = unknown"],
       ["Negative / out-of-range", "quantity = -2", "amount = -10.00"],
       ["Future date/time", "2099-12-31", "2099-12-31T00:00:00+00:00"],
       ["Unparseable date/time", "2026-13-45", "31/13/2026 25:61"],
       ["Case / whitespace labels", "'  COMPLETED '", "' SUCCESS '"],
       ["Invalid value", "country = ZZ", "orphan order_id (injected + natural)"],
       ["Duplicate key (different content)", "order_id O00000001 repeated", "txn_id T00000001 repeated"],
       ["Exact duplicate row", "whole row copied", "whole row copied"]], [50, 61, 61])
note("The same <b>seed</b> always gives the same files, so your result is reproducible (the report stores the SHA-256 fingerprint of each file). "
     "Only about 0.1%-0.5% of rows get each anomaly; roughly 4.8% of payments point to a non-existent order (natural orphans). "
     "Keeping the dirt small and <i>measured</i> means the data is still useful and you can prove each rule caught what it should. "
     "If half the data were bad, nothing could be called trustworthy.")
evidence("dirty_data_report.json (copy into evidence/). README section 4 contains the 'why small fraction' answer.")

h1("Step 5 - Upload files to the volume and count rows")
bl(["Databricks UI: <b>New > Add or upload data > Upload files to a volume</b>; choose ecom_poc.raw_files; upload both CSVs.",
    "Run the remaining cells of notebook 01 (<font face='Courier'>LIST ...</font> and <font face='Courier'>CREATE TABLE source_inventory</font>)."])
note("<b>source_inventory</b> counts the lines of each file as plain text and subtracts the header. This is an independent count: it does not rely on the "
     "same CSV reader as Bronze, so comparing the two means something. Expected: 1,000,000 each.")
evidence("06_upload.png (files in volume with size), 07_source_inventory.png (path, bytes, rows). Do not invent numbers: read them from the output.")

h1("Step 6 - Bronze: lossless ingestion")
p("Run <font face='Courier'>notebooks/02_bronze_ingestion.sql</font>. Key idea in code:")
code("""INSERT INTO bronze_orders
SELECT <all columns as STRING>, current_timestamp(), _metadata.file_path, batch_id, <_row_id>, sha2(...)
FROM read_files('/Volumes/.../orders.csv', format=>'csv', header=>true, inferSchema=>false, ...)
WHERE NOT EXISTS (SELECT 1 FROM bronze_orders b WHERE b._batch_id = batch_id);""")
table([["Audit column", "Meaning (simple)"],
       ["_ingested_at", "When we loaded the row"],
       ["_source_file", "Which file it came from"],
       ["_batch_id", "Which load it belongs to. Same batch twice = nothing inserted (idempotent)"],
       ["_row_id", "A unique ticket number for the row; follows it through quarantine/duplicates/Silver"],
       ["_row_hash", "Fingerprint of the content; same fingerprint = identical row"]], [38, 134])
note("<b>Why keep bad data in Bronze?</b> Bronze is evidence. If we threw bad rows away at the door we could never prove what the supplier sent, "
     "never re-run with better rules, and the counts could never match. <b>Why STRING?</b> A text column accepts anything ('abc' in a price field), "
     "so loading can never fail or lose data. <b>Idempotent</b> means 'running twice gives the same result as running once'.")
bl(["Check parity: the last cells show source rows vs Bronze rows and PASS.",
    "Re-run the two INSERT cells: counts must not change (this is your idempotency demonstration)."])
evidence("08_bronze_schema.png (DESCRIBE), 09_bronze_sample.png, 10_bronze_parity.png, 11_idempotency.png.")

h1("Step 7 - Silver: type, validate, quarantine, deduplicate, reconcile")
p("Run <font face='Courier'>notebooks/03_silver_quality.sql</font> (then <font face='Courier'>sql/01_rules_matrix.sql</font>).")
h3("7.1 Safe typing")
code("""try_cast(nullif(trim(quantity), '')   AS INT)            -> NULL if it cannot be read
try_cast(nullif(trim(unit_price), '') AS DECIMAL(18,2))
try_cast(nullif(trim(order_date), '') AS DATE)""")
note("A normal cast crashes on 'not_available'. <b>try_cast</b> returns NULL instead. A NULL where a value is required then fails the rule check, "
     "so the row is quarantined with a reason, not lost and not crashing the job.")
h3("7.2 The rule matrix (each failure adds a label to rejection_reason)")
table([["Field", "Rule", "Label"],
       ["quantity", "present, integer, 1-100", "missing_quantity / invalid_quantity_type / quantity_out_of_range"],
       ["unit_price", "present, decimal, >0 and <=100000", "missing_unit_price / invalid_unit_price_type / unit_price_out_of_range"],
       ["order_date", "present, valid date, not future", "missing_order_date / invalid_order_date / future_order_date"],
       ["category, status, country", "in allowed list after trim + lowercase", "invalid_category / invalid_order_status / unsupported_country"],
       ["amount", "present, decimal, >0", "missing_amount / invalid_amount_type / amount_out_of_range"],
       ["currency, status, method", "in allowed list", "unsupported_currency / invalid_txn_status / unsupported_payment_method"],
       ["txn_ts", "present, valid, not future", "missing_txn_ts / invalid_txn_timestamp / future_txn_timestamp"],
       ["transaction order_id", "must exist and be accepted", "orphan_order_id / parent_order_rejected"]], [34, 56, 82])
h3("7.3 Deterministic de-duplication")
code("""row_number() OVER (PARTITION BY order_id_c ORDER BY _row_hash, _row_id) = 1   -> winner (silver_orders)
rn > 1 -> duplicate_losers_orders, with dup_type =
          exact_duplicate_row        (same key AND same content)
          conflicting_key_duplicate  (same key, different content)""")
note("Many rows can share an order_id. We must keep exactly one. 'Deterministic' means the same input always gives the same winner, "
     "so re-runs never change results. We never delete the others: they are stored as duplicate losers.")
h3("7.4 Reconciliation")
bl(["The notebook prints a table <b>silver_reconciliation</b>: bronze_rows, accepted, quarantined, duplicate_losers and PASS/FAIL for orders and transactions.",
    "A view <b>silver_row_outcomes</b> lists every _row_id with its single outcome; notebook 05 proves no id appears twice and none is missing."])
evidence("12_rules_matrix.png, 13_typing_examples.png, 14_rule_counts.png, 15_dedup_winner_loser.png, 16_reconciliation.png (BOTH datasets PASS), 17_quarantine_sample.png.")
warn("If reconciliation says FAIL, do not edit the check. Find which rows are in no bucket or two buckets using silver_row_outcomes.")

h1("Step 8 - Gold: four business marts")
p("Run <font face='Courier'>notebooks/04_gold_models.sql</font>.")
h3("Revenue definition (write it exactly like this in your README)")
bl(["Eligible order: status <b>completed</b> or <b>delivered</b>.",
    "Accepted payment: <b>success</b> and <b>USD</b>; if an order has several, the earliest by time (then txn_id) is the only one counted.",
    "Not revenue: cancelled/pending/returned orders, failed/pending/refunded payments, EUR/GBP payments (no currency conversion), duplicates, orphans, quarantined rows, repeat payments.",
    "Source of truth: view <b>revenue_base_vw</b> = silver_transactions joined to silver_orders, one row per eligible order."])
note("Worked example: order A is completed and has two USD successful payments of 100 and 100. Revenue is 100, not 200, because only the first payment counts. "
     "If you joined orders to payments without choosing one payment, the order would appear twice and revenue would double.")
table([["Gold table", "Grain (one row per...)", "Key"],
       ["gold_daily_sales", "order date: revenue, orders, cancelled orders, cancellation rate", "order_date"],
       ["gold_revenue_breakdown", "category + country", "category, country"],
       ["gold_payment_success", "payment method: attempts, successes, success rate", "payment_method"],
       ["gold_top_customers", "customer with spend rank", "customer_id"]], [44, 98, 30])
note("Cancellation rate uses <i>all</i> accepted orders of the day. (A common mistake is computing it from revenue orders only: cancelled orders are never revenue, so the rate would always be 0.) "
     "Comments on tables and columns state the grain and meaning, so nobody sums a rate or mixes currencies by accident.")
evidence("18_gold_tables.png (names, row counts, samples), 19_gold_comments.png (Catalog Explorer comments/properties).")

h1("Step 9 - Acceptance checks")
p("Run <font face='Courier'>notebooks/05_quality_checks.sql</font>. It writes <b>quality_check_results</b> with PASS/FAIL for:")
bl(["source rows = Bronze rows (both files) and exactly 1,000,000 each",
    "bronze = accepted + quarantined + duplicate losers; no overlap, no gap by _row_id",
    "Silver keys unique; no orphan transactions in Silver",
    "Gold keys unique; revenue equal in all Gold tables and equal to an independently written query; cancellation rate not all zero"])
note("These are automatic exams for your data. The last cell stops the job with an error if any check is not PASS, so a broken run can never look successful.")
evidence("20_quality_checks.png (all PASS).")
story.append(PageBreak())

h1("Step 10 - Databricks AI/BI dashboard")
p("Follow <font face='Courier'>dashboards/dashboard_spec.md</font>. Build from the datasets in <font face='Courier'>sql/04_dashboard_datasets.sql</font>.")
table([["Widget", "Type"],
       ["Total revenue, revenue orders, average order value, cancellation rate", "4 Counters (KPIs)"],
       ["Revenue by order_date", "Line chart (time trend)"],
       ["Revenue by category / revenue by country", "2 Bar charts (breakdowns)"],
       ["Date range on order_date", "1 filter shared by all datasets"]], [120, 52])
note("A KPI counter is one big number. The shared filter is one control that updates every chart. Average order value must be a sum divided by a sum, never an average of daily averages.")
evidence("21_dashboard.png and the share link (or File > Export if sharing is restricted).")

h1("Step 11 - Genie Agent (natural-language questions)")
bl(["Create a Genie space over the four gold_* tables only; add the revenue definition as an instruction.",
    "Ask the three questions in <font face='Courier'>sql/05_genie_verification.sql</font>; open 'Show generated code' for each.",
    "Run the trusted SQL and compare. Fill <font face='Courier'>dashboards/genie_checks.md</font> (question, Genie answer, SQL result, match/mismatch, reason)."])
note("Genie turns English into SQL. AI can misunderstand, so you always verify its answer with your own trusted SQL.")
warn("If Genie is not available in your trial, screenshot the restriction and submit the three prompts + verification SQL as the fallback (the assignment allows it).")
evidence("22_genie.png or 22_genie_unavailable.png, plus the SQL results.")

h1("Step 12 - Power BI Desktop")
bl(["Get Data > Databricks; use the SQL warehouse server hostname + HTTP path (Connection details tab). Choose <b>Import</b>.",
    "Add the measures from powerbi/measures.dax (Total Revenue, Revenue Orders, Average Order Value, Cancellation Rate, Payment Success Rate).",
    "Build one page: 4 KPI cards, a line trend, a category chart, slicers. Save the .pbix and a screenshot.",
    "Compare <b>Total Revenue</b> in SQL, AI/BI and Power BI for the same dates (2026-01-01 to 2026-12-31), USD, same filters."])
table([["", "Import", "DirectQuery"],
       ["Data location", "Copied into the .pbix", "Stays in Databricks, queried live"],
       ["Speed", "Fast", "Slower; each click is a query"],
       ["Freshness", "As of last Refresh", "Always current"],
       ["Credits", "Warehouse can be stopped", "Warehouse must be running"],
       ["Our choice", "Import (small Gold data, saves credits)", ""]], [32, 70, 70])
note("If the numbers differ, check: rounding, date range, currency, stale Import (click Refresh), or a measure built on the wrong table. The checklist is in sql/03_cross_tool_validation.sql. "
     "If the connector is blocked, export Gold CSVs and say so (allowed fallback).")
evidence("23_powerbi_connection.png (mask secrets), 24_powerbi_report.png, powerbi/*.pbix, 25_revenue_comparison.png + the filled comparison table.")

h1("Step 13 - Lakeflow Job: Bronze -> Silver -> Gold")
bl(["Jobs & Pipelines > Create > Job. Add tasks <b>bronze_ingestion</b>, <b>silver_quality</b> (depends on bronze), <b>gold_models</b> (depends on silver), <b>quality_checks</b> (depends on gold). Point each to the matching notebook.",
    "Set retries to 2 on the first three. Add your email for failure (and success) notifications. Do <b>not</b> add a schedule.",
    "Click Run now once and wait for success. (YAML version: operations/lakeflow_job.yml.)"])
note("Task dependencies are arrows: a task starts only when the one before it succeeds. If Silver fails, Gold is marked 'Upstream failed' and does not run. "
     "That is the default on purpose: Gold would otherwise publish numbers from broken or old Silver data. A missing report is safer than a wrong one. "
     "Retries help with temporary problems (a slow warehouse); they do not fix bad logic.")
warn("Re-running Bronze with the same batch id inserts nothing, so the job is safe to run twice. To ingest a new file version, change the batch id label.")
evidence("26_job_graph.png, 27_job_run_success.png, 28_job_settings.png (retries + notifications).")

h1("Step 14 - Least-privilege security")
bl(["Run <font face='Courier'>sql/02_grants_least_privilege.sql</font> (needs permission to manage groups).",
    "Reporting users get: USE CATALOG, USE SCHEMA, SELECT on the four gold tables only. No Bronze, Silver, quarantine or volume access.",
    "Test: SELECT from gold works; SELECT from silver_orders must fail. Follow operations/permissions_test_plan.md.",
    "If user admin is blocked, submit the grants as the executable plan plus SHOW GRANTS output and the explanation."])
note("Least privilege = give people only the keys they need. Reporting people need finished numbers, not raw or rejected data.")
evidence("29_permissions.png (or grant plan + restriction note).")

h1("Step 15 - Cleanup before the trial ends")
bl(["Check remaining credits and screenshot them.", "Stop the SQL warehouse; confirm no compute is running; confirm the job has no schedule.",
    "Export notebooks and dashboard, commit and push to Git, revoke any Power BI token.", "Tick every item in operations/cleanup_checklist.md."])
evidence("30_credits.png, 31_warehouse_stopped.png, 32_no_schedule.png.")

h1("Step 16 - Assemble and submit")
code("""repo/
  README.md        generator/        notebooks/        sql/
  dashboards/      powerbi/ (.pbix + png)               evidence/       operations/""")
bl(["Fill every <b>[FILL]</b> in README.md with real values from your workspace. Disclose every limitation and fallback.",
    "Delete nothing that proves execution; do not include CSVs, tokens or personal data.",
    "Submit the Git repository URL or a ZIP before <b>19 November 2026</b>."])
story.append(PageBreak())

# ------------------------------------------------------------------ APPENDICES
h1("Appendix A - Assignment coverage matrix")
sm("Every requirement of the assignment mapped to where this package answers it.")
table([["Assignment requirement", "Where"],
       ["Own-email trial, record URL/region/dates/credits, restrictions; trial vs Free Edition", "Step 1; README s2"],
       ["Unity Catalog schema ecom_poc + managed volume raw_files, naming standard, exact path", "Step 2; notebooks/01; README s3"],
       ["Notebook compute + SQL warehouse, why, minimise credits", "Step 3; README s2"],
       ["Git folder, commit each stage; document limitation", "Step 2; README s3"],
       ["Generator, exactly 1M rows each, >=5 dirty categories, report counts/fractions, why small", "Step 4; generator; README s4"],
       ["Upload, exact row count (no header), bytes, path", "Step 5; source_inventory"],
       ["Why not commit data/credentials; production controls; .gitignore", "README s4; .gitignore"],
       ["Bronze all STRING, no inference; why malformed stays; audit fields explained", "Step 6; notebook 02; README s5"],
       ["Lossless count parity; re-run no double count", "Step 6; notebook 02, 05"],
       ["try_cast conversions, before/after, unparseable behaviour", "Step 7.1; notebook 03"],
       ["Rule matrix incl. orphans; counts by rule", "Step 7.2; sql/01; silver_rule_counts"],
       ["Deterministic dedupe, exact vs key duplicates, winners/losers sample", "Step 7.3; notebook 03"],
       ["Quarantine with reasons; reconciliation both datasets; no overlap", "Step 7.4; notebooks 03, 05"],
       ["Revenue definition + example + source of truth", "Step 8; README s7"],
       ["Four Gold marts, no multiplication, row counts/samples", "Step 8; notebook 04"],
       ["Table/column descriptions, grain, key, why documentation matters", "Step 8; notebook 04; README s7"],
       ["AI/BI dashboard: 4 KPIs, trend, 2 breakdowns, shared filter", "Step 10; dashboards/"],
       ["Genie 3 questions + SQL verification, or fallback", "Step 11; sql/05; genie_checks.md"],
       ["Power BI connect, Import vs DirectQuery, 4+ measures, one page, .pbix", "Step 12; powerbi/"],
       ["Equal revenue in SQL, AI/BI, Power BI; diagnose mismatch", "Step 12; sql/03; powerbi_instructions.md"],
       ["Lakeflow job tasks, dependencies, retries, notifications, run once, why Gold stops", "Step 13; operations/"],
       ["Least-privilege Gold-only grants/test or plan", "Step 14; sql/02; operations/"],
       ["Stop warehouses, schedules off, credits, export before expiry", "Step 15; cleanup_checklist"],
       ["Submission folder structure and acceptance checks", "Step 16; README s11"]], [118, 54])

h1("Appendix B - Troubleshooting")
table([["Problem", "What to try"],
       ["'Catalog not found' / cannot create schema", "Use a catalog you can write to; re-run tools/set_catalog.py with its name; note the limitation."],
       ["read_files cannot find the file", "Check the exact path with LIST on the volume; the path is case-sensitive."],
       ["Bronze count is 0 on re-run", "Expected: the batch id already exists. Change the batch id only for a new file version."],
       ["Bronze count differs from source", "Check no file was uploaded twice or partially; compare bytes; re-upload and load with a new batch id after truncating the Bronze table only if you are sure."],
       ["Reconciliation FAIL", "Query silver_row_outcomes for _row_id with count <> 1 or missing from outcomes."],
       ["Syntax error on a Databricks SQL feature (QUALIFY, nullValue, DECLARE VARIABLE)", "Use serverless compute or a recent SQL warehouse; otherwise rewrite with a subquery/CTE. The SQL was not executed by the author, so small syntax fixes may be needed."],
       ["Genie or dashboard sharing missing", "Document the restriction; use the allowed fallback."],
       ["Power BI cannot connect", "Check hostname/HTTP path, sign-in method, warehouse running; else use Gold-only CSV fallback."],
       ["Revenue differs between tools", "See sql/03_cross_tool_validation.sql checklist."]], [60, 112])

h1("Appendix C - Glossary")
table([["Term", "Meaning"],
       ["Medallion architecture", "Bronze (raw) > Silver (trusted) > Gold (business-ready) layers"],
       ["Unity Catalog", "Databricks governance layer: catalogs, schemas, tables, volumes, permissions, lineage"],
       ["Volume", "A governed folder for files inside Unity Catalog"],
       ["Delta table", "Reliable table format with history and ACID transactions"],
       ["Idempotent", "Running again gives the same result; no double loading"],
       ["Quarantine", "A labelled table for rejected rows; nothing is silently deleted"],
       ["Grain", "What one row in a table represents (e.g. one row per day)"],
       ["Reconciliation", "Proving that counts add up with nothing lost or double counted"],
       ["Lakeflow Job", "Databricks orchestrator that runs tasks in order with retries and alerts"],
       ["Import / DirectQuery", "Power BI copies data vs queries the source live"]], [42, 130])
sm("End of guide.")

doc = BaseDocTemplate(out, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm, bottomMargin=18 * mm,
                      title="Databricks Medallion Assignment - Step-by-step guide", author="")
doc.addPageTemplates([PageTemplate(id="p", frames=[Frame(18 * mm, 18 * mm, 174 * mm, 263 * mm, id="f")], onPage=footer)])
doc.build(story)
print("wrote", out)
