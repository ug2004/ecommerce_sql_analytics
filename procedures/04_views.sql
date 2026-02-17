-- ================================================
-- MATERIALIZED VIEWS (For Performance)
-- ================================================

-- View 1: Customer Summary View
-- ================================================
CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.country,
    c.segment,
    c.registration_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS lifetime_value,
    COALESCE(AVG(o.total_amount), 0) AS avg_order_value,
    MAX(o.order_date) AS last_order_date,
    CURRENT_DATE - MAX(o.order_date)::date AS days_since_last_order
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.country, c.segment, c.registration_date;

-- Test it
SELECT * FROM vw_customer_summary ORDER BY lifetime_value DESC LIMIT 10;


-- ================================================
-- View 2: Product Performance View
-- ================================================
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    c.category_name,
    s.supplier_name,
    p.price,
    p.cost,
    p.price - p.cost AS profit_per_unit,
    COUNT(DISTINCT oi.order_id) AS times_ordered,
    COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
    COALESCE(SUM(oi.line_total), 0) AS total_revenue,
    COALESCE(SUM(oi.line_total - (oi.quantity * p.cost)), 0) AS total_profit,
    COALESCE(AVG(r.rating), 0) AS avg_rating,
    COUNT(r.review_id) AS review_count,
    SUM(i.stock_quantity) AS total_stock
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN reviews r ON p.product_id = r.product_id
LEFT JOIN inventory i ON p.product_id = i.product_id
WHERE p.active = TRUE
GROUP BY p.product_id, p.product_name, p.sku, c.category_name, s.supplier_name, p.price, p.cost;

-- Test it
SELECT * FROM vw_product_performance ORDER BY total_revenue DESC LIMIT 10;


-- ================================================
-- View 3: Daily Sales Dashboard
-- ================================================
CREATE OR REPLACE VIEW vw_daily_sales AS
SELECT 
    order_date::date AS sale_date,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(total_amount) AS daily_revenue,
    AVG(total_amount) AS avg_order_value,
    SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(discount_amount) AS total_discounts
FROM orders
GROUP BY order_date::date;

-- Test it
SELECT * FROM vw_daily_sales ORDER BY sale_date DESC LIMIT 30;


-- ================================================
-- View 4: Inventory Status View
-- ================================================
CREATE OR REPLACE VIEW vw_inventory_status AS
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    w.warehouse_name,
    i.stock_quantity,
    i.reorder_level,
    CASE 
        WHEN i.stock_quantity = 0 THEN 'Out of Stock'
        WHEN i.stock_quantity <= i.reorder_level THEN 'Low Stock'
        WHEN i.stock_quantity <= i.reorder_level * 2 THEN 'Medium Stock'
        ELSE 'Good Stock'
    END AS stock_status,
    i.last_restocked_date,
    p.price * i.stock_quantity AS inventory_value
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN warehouses w ON i.warehouse_id = w.warehouse_id;

-- Test it
SELECT * FROM vw_inventory_status WHERE stock_status = 'Low Stock';


-- ================================================
-- View 5: Monthly Revenue Summary
-- ================================================
CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(total_amount) AS monthly_revenue,
    AVG(total_amount) AS avg_order_value,
    SUM(discount_amount) AS total_discounts,
    SUM(shipping_cost) AS total_shipping_revenue
FROM orders
WHERE status NOT IN ('Cancelled')
GROUP BY DATE_TRUNC('month', order_date);

-- Test it
SELECT * FROM vw_monthly_revenue ORDER BY month DESC;
