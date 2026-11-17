"""Replace the YOUR_CATALOG placeholder in all notebooks/sql/operations files.

Usage (from the final_submission folder):
    python tools/set_catalog.py my_catalog_name
It edits files in place. Run it on a COPY if you also want to keep the placeholder.
"""
import sys
from pathlib import Path

if len(sys.argv) != 2 or not sys.argv[1].replace("_", "").isalnum():
    sys.exit("usage: python tools/set_catalog.py <catalog_name>  (letters, digits, _ only)")

root = Path(__file__).resolve().parent.parent
count = 0
for folder in ("notebooks", "sql", "operations", "dashboards", "powerbi"):
    for p in (root / folder).rglob("*"):
        if p.suffix in {".sql", ".yml", ".yaml", ".md", ".dax"}:
            text = p.read_text(encoding="utf-8")
            if "YOUR_CATALOG" in text:
                p.write_text(text.replace("YOUR_CATALOG", sys.argv[1]), encoding="utf-8")
                count += 1
print(f"updated {count} files")
