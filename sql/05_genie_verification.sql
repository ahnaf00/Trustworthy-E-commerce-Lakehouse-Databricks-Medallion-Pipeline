-- Genie Agent: three business questions + trusted SQL to verify each answer.
-- Add ONLY the four gold_* tables to the Genie space. Add this instruction text to the space:
--   "Revenue means the revenue column in gold_daily_sales / gold_revenue_breakdown (USD, completed or
--    delivered orders, one successful payment per order). cancellation_rate = cancelled_orders / total_orders."
-- If Genie is not available in your trial: screenshot the restriction and submit these prompts + SQL as the fallback.
USE CATALOG workspace;
USE SCHEMA ecom_poc;

-- Q1 "What was total revenue in 2026 and how many orders produced it?"
SELECT SUM(revenue) AS total_revenue, SUM(revenue_orders) AS revenue_orders
FROM gold_daily_sales WHERE order_date BETWEEN DATE '2026-01-01' AND DATE '2026-12-31';

-- Q2 "Which category and country combination earned the most revenue?"
SELECT category, country, revenue FROM gold_revenue_breakdown ORDER BY revenue DESC LIMIT 1;

-- Q3 "Which payment method has the highest success rate?"
SELECT payment_method, success_rate FROM gold_payment_success ORDER BY success_rate DESC LIMIT 1;

-- Bonus: "Which 5 customers spent the most?"
SELECT customer_id, total_spend FROM gold_top_customers ORDER BY spend_rank LIMIT 5;

-- HOW TO CROSS-CHECK: run Genie's "Show generated code", compare its SQL result with the query
-- above. Record in dashboards/genie_checks.md: question, Genie answer, trusted SQL result, MATCH/MISMATCH,
-- and the reason for any mismatch (typical: Genie summed a different column or ignored a filter).
