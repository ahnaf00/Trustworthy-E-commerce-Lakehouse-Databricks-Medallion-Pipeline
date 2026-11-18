# Genie checks (fill from your own workspace)

Verification SQL is in `sql/05_genie_verification.sql`. Never paste an answer you did not see.

| # | Question asked | Genie answer (screenshot) | Trusted SQL result | Match? | Reason if mismatch |
|---|----------------|---------------------------|--------------------|--------|--------------------|
| 1 | What was total revenue in 2026 and how many orders produced it? | Revenue: $10,480,045.10, Orders: 23,183 | $10,480,045.10 / 23,183 orders | MATCH | Exact match with gold_daily_sales SUM(revenue) |
| 2 | Which category and country combination earned the most revenue? | Beauty / AU with $294,499.38 (632 orders) | Beauty / AU with $294,499.38 | MATCH | Exact match with gold_revenue_breakdown top row |
| 3 | Which payment method has the highest success rate? | Bank transfer at 25.25% (45,149 / 178,793) | Bank transfer at 25.25% | MATCH | Exact match with gold_payment_success top row |

**If Genie is unavailable:** record the exact restriction message + screenshot of where it is missing, keep the three prompts and SQL above as the intended-prompt fallback, and state this in the README "Limitations" section.
