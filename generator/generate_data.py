"""Generate deterministic, deliberately dirty, SYNTHETIC e-commerce CSV files.

Usage:
    python generate_data.py --output-dir ./generated --seed 20261117

Writes exactly 1,000,000 DATA rows (plus one header line) to each of:
    orders.csv, transactions.csv
and a dirty_data_report.json that lists every injected anomaly category with its
count and fraction, plus each file's byte size and SHA-256 (so a re-run with the
same seed can be proven identical).

No real customer data is used: every id, price and date comes from the seeded
random number generator. The same seed always gives the same files.

Anomaly coverage (>= 5 categories per file, all required types covered):
  orders       : blank value, text in numeric field, negative number, future date,
                 unparseable date, case/whitespace label, invalid country,
                 duplicate key (conflicting content), exact duplicate row
  transactions : blank value, text in numeric field, negative number, future
                 timestamp, unparseable timestamp, case/whitespace label,
                 orphan order id (injected AND naturally occurring),
                 duplicate key (conflicting content), exact duplicate row
Note: a single row can receive more than one anomaly; counts are per injection.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

N = 1_000_000
BASE_TS = datetime(2026, 1, 1, tzinfo=timezone.utc)
CATEGORIES = ["Electronics", "Home", "Beauty", "Sports", "Books", "Grocery"]
COUNTRIES = ["US", "GB", "CA", "AU", "DE", "FR", "SG"]
PAYMENT_METHODS = ["card", "paypal", "bank_transfer", "wallet"]
CURRENCIES = ["USD", "EUR", "GBP"]
ORDER_STATUSES = ["completed", "delivered", "cancelled", "pending", "returned"]
TXN_STATUSES = ["success", "failed", "refunded", "pending"]


def money(rng: random.Random) -> str:
    return f"{rng.uniform(3.0, 900.0):.2f}"


def write_orders(path: Path, rng: random.Random, report: Counter) -> int:
    fields = ["order_id", "customer_id", "order_date", "category", "quantity",
              "unit_price", "order_status", "country"]
    written = 0
    prev: dict | None = None      # previous row exactly as written
    prev_clean = False            # True if previous row received no anomaly
    pending_exact_dup = False
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        for i in range(1, N + 1):
            # The random draws below always happen, in this order, so the stream
            # (and therefore every other value) never depends on the anomalies.
            row = {
                "order_id": f"O{i:08d}",
                "customer_id": f"C{rng.randint(1, 250_000):07d}",
                "order_date": (BASE_TS + timedelta(days=rng.randrange(365))).strftime("%Y-%m-%d"),
                "category": rng.choice(CATEGORIES),
                "quantity": str(rng.randint(1, 5)),
                "unit_price": money(rng),
                "order_status": rng.choice(ORDER_STATUSES),
                "country": rng.choice(COUNTRIES),
            }
            if i % 40_000 == 0:
                pending_exact_dup = True
            if pending_exact_dup and prev is not None and prev_clean:
                # Exact duplicate: identical to the previous (clean) row, all fields.
                row = dict(prev)
                report["orders.exact_duplicate_row"] += 1
                pending_exact_dup = False
                dirty = False
            else:
                dirty = False
                if i % 200 == 0:
                    row["quantity"] = ""; report["orders.null_or_blank"] += 1; dirty = True
                if i % 333 == 0:
                    row["unit_price"] = "not_available"; report["orders.text_numeric"] += 1; dirty = True
                if i % 401 == 0:
                    row["quantity"] = "-2"; report["orders.negative_quantity"] += 1; dirty = True
                if i % 503 == 0:
                    row["order_date"] = "2099-12-31"; report["orders.future_date"] += 1; dirty = True
                if i % 811 == 0:
                    row["order_date"] = "2026-13-45"; report["orders.unparseable_date"] += 1; dirty = True
                if i % 607 == 0:
                    row["order_status"] = "  COMPLETED "; report["orders.label_whitespace_case"] += 1; dirty = True
                if i % 701 == 0:
                    row["country"] = "ZZ"; report["orders.invalid_country"] += 1; dirty = True
                if i <= 25_000 and i % 5_000 == 0:
                    row["order_id"] = "O00000001"; report["orders.duplicate_key"] += 1; dirty = True
            writer.writerow(row)
            written += 1
            prev, prev_clean = row, not dirty
    return written


def write_transactions(path: Path, rng: random.Random, report: Counter) -> int:
    fields = ["txn_id", "order_id", "payment_method", "amount", "currency",
              "txn_status", "txn_ts"]
    written = 0
    prev: dict | None = None
    prev_clean = False
    pending_exact_dup = False
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        for i in range(1, N + 1):
            order_number = rng.randint(1, N + 50_000)
            row = {
                "txn_id": f"T{i:08d}",
                "order_id": f"O{order_number:08d}",
                "payment_method": rng.choice(PAYMENT_METHODS),
                "amount": money(rng),
                "currency": rng.choice(CURRENCIES),
                "txn_status": rng.choice(TXN_STATUSES),
                "txn_ts": (BASE_TS + timedelta(minutes=rng.randrange(525_600))).isoformat(),
            }
            natural_orphan = order_number > N   # orders only go up to N
            if i % 45_000 == 0:
                pending_exact_dup = True
            if pending_exact_dup and prev is not None and prev_clean:
                row = dict(prev)
                report["transactions.exact_duplicate_row"] += 1
                pending_exact_dup = False
                dirty = False
            else:
                dirty = False
                if natural_orphan:
                    report["transactions.orphan_order_natural"] += 1; dirty = True
                if i % 211 == 0:
                    row["amount"] = ""; report["transactions.null_or_blank"] += 1; dirty = True
                if i % 307 == 0:
                    row["amount"] = "unknown"; report["transactions.text_numeric"] += 1; dirty = True
                if i % 419 == 0:
                    row["amount"] = "-10.00"; report["transactions.negative_amount"] += 1; dirty = True
                if i % 521 == 0:
                    row["txn_ts"] = "2099-12-31T00:00:00+00:00"; report["transactions.future_timestamp"] += 1; dirty = True
                if i % 809 == 0:
                    row["txn_ts"] = "31/13/2026 25:61"; report["transactions.unparseable_timestamp"] += 1; dirty = True
                if i % 613 == 0:
                    row["txn_status"] = " SUCCESS "; report["transactions.label_whitespace_case"] += 1; dirty = True
                if i % 719 == 0:
                    row["order_id"] = f"O{N + i:08d}"; report["transactions.orphan_order_injected"] += 1; dirty = True
                if i <= 30_000 and i % 6_000 == 0:
                    row["txn_id"] = "T00000001"; report["transactions.duplicate_key"] += 1; dirty = True
            writer.writerow(row)
            written += 1
            prev, prev_clean = row, not dirty
    return written


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261117)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    rng = random.Random(args.seed)
    orders_report: Counter = Counter()
    txn_report: Counter = Counter()
    orders_path = args.output_dir / "orders.csv"
    txn_path = args.output_dir / "transactions.csv"

    n_orders = write_orders(orders_path, rng, orders_report)
    n_txn = write_transactions(txn_path, rng, txn_report)
    assert n_orders == N and n_txn == N, "row count must be exactly 1,000,000"

    anomalies = {**orders_report, **txn_report}
    payload = {
        "seed": args.seed,
        "rows_per_file": N,
        "data_rows_written": {"orders.csv": n_orders, "transactions.csv": n_txn},
        "file_bytes": {"orders.csv": orders_path.stat().st_size,
                       "transactions.csv": txn_path.stat().st_size},
        "file_sha256": {"orders.csv": sha256_of(orders_path),
                        "transactions.csv": sha256_of(txn_path)},
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "anomalies": dict(sorted(anomalies.items())),
        "anomaly_fraction_of_file": {k: round(v / N, 6) for k, v in sorted(anomalies.items())},
        "note": "A row can carry more than one anomaly; counts are per injection.",
    }
    (args.output_dir / "dirty_data_report.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
