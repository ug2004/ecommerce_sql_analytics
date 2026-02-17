-- ================================================
-- ADVANCED ANALYTICS QUERIES
-- ================================================

-- Query 1: Product Affinity Analysis (Market Basket)
-- Purpose: Find products frequently bought together
-- ================================================
WITH product_pairs AS (
    SELECT 
        oi1.product_id AS product_a,
        oi2.product_id AS product_b,
        COUNT(DISTINCT oi1.order_id) AS times_bought_together
    FROM order_items oi1
    JOIN order_items oi2 ON oi1.order_id = oi2.order_id 
        AND oi1.product_id < oi2.product_id
    GROUP BY oi1.product_id, oi2.product_id
    HAVING COUNT(DISTINCT oi1.order_id) >= 5
)
SELECT 
    p1.product_name AS product_a,
    p2.product_name AS product_b,
    pp.times_bought_together,
    ROUND(100.0 * pp.times_bought_together / 
        (SELECT COUNT(DISTINCT order_id) FROM order_items WHERE product_id = pp.product_a), 2) AS confidence_pct
FROM product_pairs pp
JOIN products p1 ON pp.product_a = p1.product_id
JOIN products p2 ON pp.product_b = p2.product_id
ORDER BY pp.times_bought_together DESC, confidence_pct DESC
LIMIT 30;


-- ================================================
-- Query 2: Customer Segmentation with Spending Patterns
-- Purpose: Advanced customer clustering
-- ================================================
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.segment,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(o.total_amount) AS total_spent,
        AVG(o.total_amount) AS avg_order_value,
        STDDEV(o.total_amount) AS order_value_stddev,
        MIN(o.order_date) AS first_order,
        MAX(o.order_date) AS last_order,
        COUNT(DISTINCT DATE_TRUNC('month', o.order_date)) AS active_months,
        CURRENT_DATE - MAX(o.order_date)::date AS recency_days
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.segment
    HAVING COUNT(o.order_id) > 0
)
SELECT 
    customer_id,
    customer_name,
    order_count,
    ROUND(total_spent, 2) AS total_spent,
    ROUND(avg_order_value, 2) AS avg_order_value,
    ROUND(order_value_stddev, 2) AS spending_consistency,
    active_months,
    recency_days,
    ROUND(total_spent / NULLIF(active_months, 0), 2) AS monthly_revenue,
    CASE 
        WHEN order_count >= 10 AND total_spent >= 1000 AND recency_days < 90 THEN 'VIP Active'
        WHEN order_count >= 5 AND total_spent >= 500 AND recency_days < 90 THEN 'High Value Active'
        WHEN order_count >= 10 AND recency_days > 180 THEN 'VIP At Risk'
        WHEN order_count >= 5 AND recency_days > 180 THEN 'High Value At Risk'
        WHEN order_count <= 2 AND recency_days < 90 THEN 'New Customer'
        WHEN recency_days > 365 THEN 'Churned'
        ELSE 'Regular'
    END AS customer_tier,
    CASE 
        WHEN order_value_stddev / NULLIF(avg_order_value, 0) < 0.3 THEN 'Consistent'
        WHEN order_value_stddev / NULLIF(avg_order_value, 0) < 0.7 THEN 'Moderate'
        ELSE 'Irregular'
    END AS buying_pattern
FROM customer_metrics
ORDER BY total_spent DESC
LIMIT 100;


-- ================================================
-- Query 3: Time Series Analysis - Sales Trends with Moving Averages
-- Purpose: Identify sales patterns and anomalies
-- ================================================
WITH daily_sales AS (
    SELECT 
        order_date::date AS sale_date,
        COUNT(order_id) AS order_count,
        SUM(total_amount) AS daily_revenue
    FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '180 days'
    GROUP BY order_date::date
)
SELECT 
    sale_date,
    order_count,
    ROUND(daily_revenue, 2) AS daily_revenue,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_7_day,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_30_day,
    ROUND(daily_revenue - AVG(daily_revenue) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS deviation_from_7day_avg,
    EXTRACT(DOW FROM sale_date) AS day_of_week,
    TO_CHAR(sale_date, 'Day') AS day_name
FROM daily_sales
ORDER BY sale_date DESC;


-- ================================================
-- Query 4: Cumulative Revenue by Customer
-- Purpose: Running total analysis
-- ================================================
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_id,
    o.order_date,
    ROUND(o.total_amount, 2) AS order_amount,
    ROUND(SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ), 2) AS cumulative_revenue,
    ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY o.order_date) AS order_number
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.customer_id IN (
    SELECT customer_id 
    FROM orders 
    GROUP BY customer_id 
    ORDER BY SUM(total_amount) DESC 
    LIMIT 10
)
ORDER BY c.customer_id, o.order_date;


-- ================================================
-- Query 5: Revenue Growth Rate Analysis
-- Purpose: Calculate month-over-month and year-over-year growth
-- ================================================
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', order_date) AS month,
        SUM(total_amount) AS revenue,
        COUNT(DISTINCT customer_id) AS customers,
        COUNT(order_id) AS orders
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT 
    month,
    ROUND(revenue, 2) AS monthly_revenue,
    customers AS active_customers,
    orders AS total_orders,
    ROUND(revenue / NULLIF(customers, 0), 2) AS revenue_per_customer,
    LAG(revenue, 1) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(revenue - LAG(revenue, 1) OVER (ORDER BY month), 2) AS mom_change,
    ROUND(100.0 * (revenue - LAG(revenue, 1) OVER (ORDER BY month)) / 
        NULLIF(LAG(revenue, 1) OVER (ORDER BY month), 0), 2) AS mom_growth_pct,
    LAG(revenue, 12) OVER (ORDER BY month) AS same_month_last_year,
    ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (ORDER BY month)) / 
        NULLIF(LAG(revenue, 12) OVER (ORDER BY month), 0), 2) AS yoy_growth_pct
FROM monthly_revenue
ORDER BY month DESC;


-- ================================================
-- Query 6: Customer Purchase Frequency Distribution
-- Purpose: Understand how often customers buy
-- ================================================
WITH purchase_frequency AS (
    SELECT 
        customer_id,
        COUNT(order_id) AS order_count,
        EXTRACT(DAY FROM (MAX(order_date) - MIN(order_date))) / NULLIF(COUNT(order_id) - 1, 0) AS avg_days_between_orders
    FROM orders
    GROUP BY customer_id
    HAVING COUNT(order_id) > 1
)
SELECT 
    CASE 
        WHEN order_count = 1 THEN '1 order'
        WHEN order_count = 2 THEN '2 orders'
        WHEN order_count BETWEEN 3 AND 5 THEN '3-5 orders'
        WHEN order_count BETWEEN 6 AND 10 THEN '6-10 orders'
        WHEN order_count BETWEEN 11 AND 20 THEN '11-20 orders'
        ELSE '20+ orders'
    END AS order_frequency_bucket,
    COUNT(*) AS customer_count,
    ROUND(AVG(order_count), 2) AS avg_orders,
    ROUND(AVG(avg_days_between_orders), 0) AS avg_days_between_orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage_of_customers
FROM purchase_frequency
GROUP BY 
    CASE 
        WHEN order_count = 1 THEN '1 order'
        WHEN order_count = 2 THEN '2 orders'
        WHEN order_count BETWEEN 3 AND 5 THEN '3-5 orders'
        WHEN order_count BETWEEN 6 AND 10 THEN '6-10 orders'
        WHEN order_count BETWEEN 11 AND 20 THEN '11-20 orders'
        ELSE '20+ orders'
    END
ORDER BY MIN(order_count);


-- ================================================
-- Query 7: Product Performance Quadrant Analysis
-- Purpose: Classify products into strategic categories
-- ================================================
WITH product_metrics AS (
    SELECT 
        p.product_id,
        p.product_name,
        c.category_name,
        COUNT(DISTINCT oi.order_id) AS order_frequency,
        SUM(oi.quantity) AS units_sold,
        SUM(oi.line_total) AS total_revenue,
        SUM(oi.line_total - (oi.quantity * p.cost)) AS total_profit,
        AVG(r.rating) AS avg_rating,
        COUNT(r.review_id) AS review_count
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN reviews r ON p.product_id = r.product_id
    WHERE p.active = TRUE
    GROUP BY p.product_id, p.product_name, c.category_name
    HAVING COUNT(oi.order_item_id) > 0
),
percentiles AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) AS median_revenue,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_profit) AS median_profit
    FROM product_metrics
)
SELECT 
    pm.product_id,
    pm.product_name,
    pm.category_name,
    pm.order_frequency,
    pm.units_sold,
    ROUND(pm.total_revenue, 2) AS total_revenue,
    ROUND(pm.total_profit, 2) AS total_profit,
    ROUND(pm.avg_rating, 2) AS avg_rating,
    pm.review_count,
    CASE 
        WHEN pm.total_revenue >= p.median_revenue AND pm.total_profit >= p.median_profit THEN 'Stars (High Revenue, High Profit)'
        WHEN pm.total_revenue >= p.median_revenue AND pm.total_profit < p.median_profit THEN 'Cash Cows (High Revenue, Low Profit)'
        WHEN pm.total_revenue < p.median_revenue AND pm.total_profit >= p.median_profit THEN 'Hidden Gems (Low Revenue, High Profit)'
        ELSE 'Dogs (Low Revenue, Low Profit)'
    END AS product_quadrant,
    CASE 
        WHEN pm.avg_rating >= 4.0 THEN 'High Satisfaction'
        WHEN pm.avg_rating >= 3.0 THEN 'Moderate Satisfaction'
        WHEN pm.avg_rating IS NOT NULL THEN 'Low Satisfaction'
        ELSE 'Not Rated'
    END AS satisfaction_level
FROM product_metrics pm
CROSS JOIN percentiles p
ORDER BY pm.total_revenue DESC;


-- ================================================
-- Query 8: Peak Shopping Hours Analysis
-- Purpose: Identify when customers shop most
-- ================================================
SELECT 
    EXTRACT(HOUR FROM order_date) AS hour_of_day,
    COUNT(order_id) AS order_count,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage_of_orders,
    CASE 
        WHEN EXTRACT(HOUR FROM order_date) BETWEEN 0 AND 5 THEN 'Late Night'
        WHEN EXTRACT(HOUR FROM order_date) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM order_date) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM order_date) BETWEEN 18 AND 23 THEN 'Evening'
    END AS time_period
FROM orders
GROUP BY EXTRACT(HOUR FROM order_date)
ORDER BY hour_of_day;


-- ================================================
-- Query 9: Customer Support Ticket Analysis
-- Purpose: Analyze support patterns and resolution efficiency
-- ================================================
SELECT 
    issue_type,
    priority,
    status,
    COUNT(*) AS ticket_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(EXTRACT(DAY FROM (COALESCE(resolved_date, CURRENT_TIMESTAMP) - created_date))), 1) AS avg_resolution_days,
    COUNT(CASE WHEN status IN ('Resolved', 'Closed') THEN 1 END) AS resolved_count,
    ROUND(100.0 * COUNT(CASE WHEN status IN ('Resolved', 'Closed') THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS resolution_rate
FROM customer_support_tickets
GROUP BY issue_type, priority, status
ORDER BY ticket_count DESC;


-- ================================================
-- Query 10: Supplier Performance Scorecard
-- Purpose: Evaluate supplier reliability and profitability
-- ================================================
SELECT 
    s.supplier_id,
    s.supplier_name,
    s.country,
    s.rating AS supplier_rating,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT oi.order_id) AS orders_fulfilled,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(SUM(oi.line_total - (oi.quantity * p.cost)), 2) AS total_profit,
    ROUND(AVG(r.rating), 2) AS avg_product_rating,
    COUNT(r.review_id) AS total_reviews,
    ROUND(100.0 * (SUM(oi.line_total - (oi.quantity * p.cost)) / NULLIF(SUM(oi.line_total), 0)), 2) AS profit_margin_pct
FROM suppliers s
JOIN products p ON s.supplier_id = p.supplier_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN reviews r ON p.product_id = r.product_id
WHERE s.active = TRUE
GROUP BY s.supplier_id, s.supplier_name, s.country, s.rating
HAVING COUNT(oi.order_item_id) > 0
ORDER BY total_revenue DESC;
