-- ================================================
-- INVENTORY & OPERATIONS ANALYTICS QUERIES
-- ================================================

-- Query 1: Current Inventory Status
-- Purpose: Monitor stock levels across all warehouses
-- ================================================
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    c.category_name,
    w.warehouse_name,
    w.city AS warehouse_city,
    i.stock_quantity,
    i.reorder_level,
    CASE 
        WHEN i.stock_quantity = 0 THEN 'Out of Stock'
        WHEN i.stock_quantity <= i.reorder_level THEN 'Low Stock'
        WHEN i.stock_quantity <= i.reorder_level * 2 THEN 'Medium Stock'
        ELSE 'Good Stock'
    END AS stock_status,
    p.price,
    ROUND(i.stock_quantity * p.price, 2) AS inventory_value,
    i.last_restocked_date,
    CURRENT_DATE - i.last_restocked_date AS days_since_restock
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
WHERE p.active = TRUE
ORDER BY 
    CASE 
        WHEN i.stock_quantity = 0 THEN 1
        WHEN i.stock_quantity <= i.reorder_level THEN 2
        ELSE 3
    END,
    i.stock_quantity ASC;


-- ================================================
-- Query 2: Products Needing Reorder
-- Purpose: Generate purchase orders for low stock items
-- ================================================
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    c.category_name,
    s.supplier_name,
    s.country AS supplier_country,
    s.contact_email,
    SUM(i.stock_quantity) AS total_stock,
    AVG(i.reorder_level) AS avg_reorder_level,
    ROUND(p.cost, 2) AS unit_cost,
    ROUND(SUM(i.reorder_level) * 2 * p.cost, 2) AS estimated_order_cost
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
JOIN inventory i ON p.product_id = i.product_id
WHERE p.active = TRUE
GROUP BY p.product_id, p.product_name, p.sku, c.category_name, s.supplier_name, s.country, s.contact_email, p.cost
HAVING SUM(i.stock_quantity) <= AVG(i.reorder_level)
ORDER BY SUM(i.stock_quantity) ASC;


-- ================================================
-- Query 3: Inventory Turnover Rate
-- Purpose: Identify fast and slow-moving products
-- ================================================
WITH product_sales AS (
    SELECT 
        p.product_id,
        p.product_name,
        c.category_name,
        SUM(oi.quantity) AS units_sold_last_90_days,
        AVG(i.stock_quantity) AS avg_stock_quantity
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_date >= CURRENT_DATE - INTERVAL '90 days'
    LEFT JOIN inventory i ON p.product_id = i.product_id
    WHERE p.active = TRUE
    GROUP BY p.product_id, p.product_name, c.category_name
)
SELECT 
    product_id,
    product_name,
    category_name,
    units_sold_last_90_days,
    ROUND(avg_stock_quantity, 0) AS avg_stock,
    CASE 
        WHEN avg_stock_quantity > 0 THEN ROUND((units_sold_last_90_days / NULLIF(avg_stock_quantity, 0)) * 4, 2)
        ELSE 0
    END AS annual_turnover_rate,
    CASE 
        WHEN avg_stock_quantity > 0 AND (units_sold_last_90_days / NULLIF(avg_stock_quantity, 0)) * 4 > 8 THEN 'Fast Moving'
        WHEN avg_stock_quantity > 0 AND (units_sold_last_90_days / NULLIF(avg_stock_quantity, 0)) * 4 > 4 THEN 'Normal'
        WHEN avg_stock_quantity > 0 AND (units_sold_last_90_days / NULLIF(avg_stock_quantity, 0)) * 4 > 1 THEN 'Slow Moving'
        WHEN units_sold_last_90_days = 0 THEN 'No Sales'
        ELSE 'Very Slow'
    END AS movement_category,
    ROUND(365.0 / NULLIF((units_sold_last_90_days / NULLIF(avg_stock_quantity, 0)) * 4, 0), 0) AS days_of_supply
FROM product_sales
WHERE avg_stock_quantity > 0
ORDER BY annual_turnover_rate DESC;


-- ================================================
-- Query 4: Dead Stock Analysis
-- Purpose: Identify products with no recent sales
-- ================================================
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    c.category_name,
    SUM(i.stock_quantity) AS total_stock,
    ROUND(p.price, 2) AS current_price,
    ROUND(SUM(i.stock_quantity) * p.price, 2) AS inventory_value,
    MAX(o.order_date) AS last_sale_date,
    CURRENT_DATE - MAX(o.order_date)::date AS days_since_last_sale,
    COUNT(oi.order_item_id) AS times_ordered_all_time
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE p.active = TRUE
GROUP BY p.product_id, p.product_name, p.sku, c.category_name, p.price
HAVING MAX(o.order_date) IS NULL OR MAX(o.order_date) < CURRENT_DATE - INTERVAL '180 days'
ORDER BY inventory_value DESC;


-- ================================================
-- Query 5: Warehouse Performance Comparison
-- Purpose: Compare efficiency across warehouses
-- ================================================
SELECT 
    w.warehouse_id,
    w.warehouse_name,
    w.city,
    w.country,
    COUNT(DISTINCT i.product_id) AS unique_products,
    SUM(i.stock_quantity) AS total_units,
    ROUND(AVG(i.stock_quantity), 2) AS avg_stock_per_product,
    ROUND(SUM(i.stock_quantity * p.price), 2) AS total_inventory_value,
    COUNT(CASE WHEN i.stock_quantity = 0 THEN 1 END) AS out_of_stock_count,
    COUNT(CASE WHEN i.stock_quantity <= i.reorder_level THEN 1 END) AS low_stock_count,
    ROUND(100.0 * COUNT(CASE WHEN i.stock_quantity = 0 THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS out_of_stock_pct
FROM warehouses w
JOIN inventory i ON w.warehouse_id = i.warehouse_id
JOIN products p ON i.product_id = p.product_id
WHERE w.active = TRUE
GROUP BY w.warehouse_id, w.warehouse_name, w.city, w.country
ORDER BY total_inventory_value DESC;


-- ================================================
-- Query 6: Inventory Age Analysis
-- Purpose: Identify old stock that may need clearance
-- ================================================
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    i.warehouse_id,
    w.warehouse_name,
    i.stock_quantity,
    i.last_restocked_date,
    CURRENT_DATE - i.last_restocked_date AS days_in_inventory,
    ROUND(p.price, 2) AS current_price,
    ROUND(i.stock_quantity * p.price, 2) AS inventory_value,
    CASE 
        WHEN CURRENT_DATE - i.last_restocked_date > 365 THEN 'Very Old (>1 year)'
        WHEN CURRENT_DATE - i.last_restocked_date > 180 THEN 'Old (6-12 months)'
        WHEN CURRENT_DATE - i.last_restocked_date > 90 THEN 'Aging (3-6 months)'
        ELSE 'Fresh (<3 months)'
    END AS age_category
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
WHERE i.stock_quantity > 0 AND i.last_restocked_date IS NOT NULL
ORDER BY days_in_inventory DESC;


-- ================================================
-- Query 7: Stock Coverage Analysis
-- Purpose: Calculate how many days current stock will last
-- ================================================
WITH daily_sales AS (
    SELECT 
        p.product_id,
        AVG(daily_quantity) AS avg_daily_sales
    FROM products p
    CROSS JOIN LATERAL (
        SELECT 
            SUM(oi.quantity) / NULLIF(COUNT(DISTINCT o.order_date::date), 0) AS daily_quantity
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE oi.product_id = p.product_id
          AND o.order_date >= CURRENT_DATE - INTERVAL '90 days'
    ) sales
    GROUP BY p.product_id
)
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    SUM(i.stock_quantity) AS total_stock,
    ROUND(ds.avg_daily_sales, 2) AS avg_daily_sales,
    CASE 
        WHEN ds.avg_daily_sales > 0 THEN ROUND(SUM(i.stock_quantity) / NULLIF(ds.avg_daily_sales, 0), 0)
        ELSE NULL
    END AS days_of_stock_remaining,
    CASE 
        WHEN ds.avg_daily_sales > 0 AND SUM(i.stock_quantity) / NULLIF(ds.avg_daily_sales, 0) < 7 THEN 'Critical'
        WHEN ds.avg_daily_sales > 0 AND SUM(i.stock_quantity) / NULLIF(ds.avg_daily_sales, 0) < 14 THEN 'Low'
        WHEN ds.avg_daily_sales > 0 AND SUM(i.stock_quantity) / NULLIF(ds.avg_daily_sales, 0) < 30 THEN 'Adequate'
        WHEN ds.avg_daily_sales > 0 THEN 'Excess'
        ELSE 'No Recent Sales'
    END AS coverage_status
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN daily_sales ds ON p.product_id = ds.product_id
WHERE p.active = TRUE
GROUP BY p.product_id, p.product_name, c.category_name, ds.avg_daily_sales
HAVING ds.avg_daily_sales IS NOT NULL
ORDER BY days_of_stock_remaining ASC NULLS LAST;
