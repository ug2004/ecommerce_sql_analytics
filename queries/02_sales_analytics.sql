-- ================================================
-- SALES ANALYTICS QUERIES
-- ================================================

-- Query 1: Daily Sales Trends
-- Purpose: Monitor daily sales performance
-- ================================================
SELECT 
    order_date::date AS sale_date,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(total_amount) AS daily_revenue,
    AVG(total_amount) AS avg_order_value,
    SUM(discount_amount) AS total_discounts,
    SUM(shipping_cost) AS total_shipping
FROM orders
WHERE order_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY order_date::date
ORDER BY sale_date DESC;


-- ================================================
-- Query 2: Monthly Sales Summary with Growth Rate
-- Purpose: Track month-over-month performance
-- ================================================
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date) AS month,
        COUNT(order_id) AS total_orders,
        SUM(total_amount) AS revenue,
        AVG(total_amount) AS avg_order_value,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT 
    month,
    total_orders,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(avg_order_value, 2) AS avg_order_value,
    unique_customers,
    ROUND(revenue / NULLIF(unique_customers, 0), 2) AS revenue_per_customer,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY month)) / 
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 
    2) AS revenue_growth_pct,
    ROUND(
        100.0 * (total_orders - LAG(total_orders) OVER (ORDER BY month)) / 
        NULLIF(LAG(total_orders) OVER (ORDER BY month), 0), 
    2) AS order_growth_pct
FROM monthly_sales
ORDER BY month DESC;


-- ================================================
-- Query 3: Revenue by Payment Method
-- Purpose: Understand payment preferences
-- ================================================
SELECT 
    payment_method,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage_of_orders,
    ROUND(100.0 * SUM(total_amount) / SUM(SUM(total_amount)) OVER (), 2) AS percentage_of_revenue
FROM orders
GROUP BY payment_method
ORDER BY total_revenue DESC;


-- ================================================
-- Query 4: Sales by Order Status
-- Purpose: Track order fulfillment
-- ================================================
SELECT 
    status,
    COUNT(*) AS order_count,
    ROUND(SUM(total_amount), 2) AS total_value,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(EXTRACT(DAY FROM (COALESCE(delivery_date, CURRENT_TIMESTAMP) - order_date))), 1) AS avg_days_to_complete
FROM orders
GROUP BY status
ORDER BY order_count DESC;


-- ================================================
-- Query 5: Top Products by Revenue
-- Purpose: Identify best-selling products
-- ================================================
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    c.category_name,
    COUNT(oi.order_item_id) AS times_sold,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS avg_selling_price,
    ROUND(SUM(oi.line_total) - SUM(oi.quantity * p.cost), 2) AS total_profit,
    ROUND(100.0 * (SUM(oi.line_total) - SUM(oi.quantity * p.cost)) / NULLIF(SUM(oi.line_total), 0), 2) AS profit_margin_pct
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY p.product_id, p.product_name, p.sku, c.category_name
ORDER BY total_revenue DESC
LIMIT 20;


-- ================================================
-- Query 6: Category Performance
-- Purpose: Compare sales across categories
-- ================================================
SELECT 
    c.category_name,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(oi.line_total), 2) AS avg_transaction_value,
    ROUND(SUM(oi.line_total) - SUM(oi.quantity * p.cost), 2) AS total_profit,
    ROUND(100.0 * (SUM(oi.line_total) - SUM(oi.quantity * p.cost)) / NULLIF(SUM(oi.line_total), 0), 2) AS profit_margin_pct
FROM categories c
LEFT JOIN products p ON c.category_id = p.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY c.category_name
HAVING COUNT(oi.order_item_id) > 0
ORDER BY total_revenue DESC;


-- ================================================
-- Query 7: Discount Impact Analysis
-- Purpose: Evaluate effectiveness of discounts
-- ================================================
WITH discount_buckets AS (
    SELECT 
        order_id,
        total_amount,
        discount_amount,
        CASE 
            WHEN discount_amount = 0 THEN 'No Discount'
            WHEN discount_amount < 10 THEN 'Low (< $10)'
            WHEN discount_amount < 25 THEN 'Medium ($10-$25)'
            ELSE 'High (> $25)'
        END AS discount_tier
    FROM orders
)
SELECT 
    discount_tier,
    COUNT(*) AS order_count,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(SUM(discount_amount), 2) AS total_discount_given,
    ROUND(100.0 * SUM(discount_amount) / NULLIF(SUM(total_amount + discount_amount), 0), 2) AS avg_discount_pct
FROM discount_buckets
GROUP BY discount_tier
ORDER BY 
    CASE discount_tier
        WHEN 'No Discount' THEN 1
        WHEN 'Low (< $10)' THEN 2
        WHEN 'Medium ($10-$25)' THEN 3
        WHEN 'High (> $25)' THEN 4
    END;
