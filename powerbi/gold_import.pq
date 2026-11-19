// Power BI Desktop > Home > Get Data > Blank Query > Advanced Editor.
// Create ONE query per table below (name each query exactly as the table), Import mode.
// Replace the two placeholders from SQL Warehouses > <warehouse> > Connection details.
// Do NOT put a token in this file. Sign in with the OAuth / token prompt in Power BI.
//
// Server hostname:  <YOUR-WORKSPACE>.cloud.databricks.com   (no https://)
// HTTP path:        /sql/1.0/warehouses/<WAREHOUSE-ID>
// Catalog / schema: workspace / ecom_poc

// ---- Query: gold_daily_sales ----
let
    Source = Databricks.Catalogs("<YOUR-WORKSPACE>.cloud.databricks.com", "/sql/1.0/warehouses/<WAREHOUSE-ID>", [Catalog = "workspace", Database = "ecom_poc", EnableAutomaticProxyDiscovery = null]),
    Schema = Source{[Name = "workspace", Kind = "Database"]}[Data],
    Tbl    = Schema{[Name = "ecom_poc", Kind = "Database"]}[Data],
    Gold   = Tbl{[Name = "gold_daily_sales", Kind = "Table"]}[Data],
    Typed  = Table.TransformColumnTypes(Gold, {{"order_date", type date}, {"revenue", Currency.Type}})
in
    Typed

// ---- Repeat for: gold_revenue_breakdown, gold_payment_success, gold_top_customers
//      (change only the Name = "..." in the Gold step; skip the Typed step, or type revenue/total_spend as Currency.Type).
// If the navigation steps error, simply use Get Data > Databricks and tick the four gold_* tables in the Navigator.
