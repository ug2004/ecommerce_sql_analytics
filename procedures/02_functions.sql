-- ================================================
-- USER-DEFINED FUNCTIONS
-- ================================================

-- Function 1: Calculate Order Profit
-- Purpose: Get profit for a specific order
-- ================================================
CREATE OR REPLACE FUNCTION calculate_order_profit(order_id_param INT)
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    order_profit DECIMAL(10,2);
BEGIN
    SELECT 
        SUM(oi.line_total - (oi.quantity * p.cost))
    INTO order_profit
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE oi.order_id = order_id_param;
    
    RETURN COALESCE(order_profit, 0);
END;
$$;

-- Test it
SELECT order_id, total_amount, calculate_order_profit(order_id) as profit
FROM orders 
LIMIT 10;


-- ================================================
-- Function 2: Get Customer Segment
-- Purpose: Determine customer segment based on spending
-- ================================================
CREATE OR REPLACE FUNCTION get_customer_segment(customer_id_param INT)
RETURNS VARCHAR(50)
LANGUAGE plpgsql
AS $$
DECLARE
    total_spending DECIMAL(12,2);
    customer_segment VARCHAR(50);
BEGIN
    SELECT COALESCE(SUM(total_amount), 0)
    INTO total_spending
    FROM orders
    WHERE customer_id = customer_id_param
      AND status NOT IN ('Cancelled');
    
    customer_segment := CASE
        WHEN total_spending >= 5000 THEN 'VIP'
        WHEN total_spending >= 2000 THEN 'Premium'
        WHEN total_spending >= 500 THEN 'Regular'
        ELSE 'New'
    END;
    
    RETURN customer_segment;
END;
$$;

-- Test it
SELECT 
    customer_id,
    first_name || ' ' || last_name as name,
    get_customer_segment(customer_id) as segment
FROM customers
LIMIT 10;


-- ================================================
-- Function 3: Calculate Product Stock Days
-- Purpose: Estimate how many days current stock will last
-- ================================================
CREATE OR REPLACE FUNCTION calculate_stock_days(product_id_param INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    current_stock INT;
    avg_daily_sales DECIMAL(10,2);
    stock_days INT;
BEGIN
    -- Get current stock
    SELECT SUM(stock_quantity)
    INTO current_stock
    FROM inventory
    WHERE product_id = product_id_param;
    
    -- Get average daily sales (last 90 days)
    SELECT 
        SUM(oi.quantity) / NULLIF(COUNT(DISTINCT o.order_date::date), 0)
    INTO avg_daily_sales
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE oi.product_id = product_id_param
      AND o.order_date >= CURRENT_DATE - INTERVAL '90 days';
    
    -- Calculate days of stock
    IF avg_daily_sales > 0 THEN
        stock_days := ROUND(current_stock / avg_daily_sales);
    ELSE
        stock_days := NULL;
    END IF;
    
    RETURN stock_days;
END;
$$;

-- Test it
SELECT 
    p.product_id,
    p.product_name,
    calculate_stock_days(p.product_id) as days_of_stock
FROM products p
LIMIT 20;


-- ================================================
-- Function 4: Get Top Products by Category
-- Purpose: Return top N products in a category
-- ================================================
CREATE OR REPLACE FUNCTION get_top_products_in_category(
    category_id_param INT,
    limit_param INT DEFAULT 5
)
RETURNS TABLE (
    product_id INT,
    product_name VARCHAR(300),
    total_revenue DECIMAL(12,2),
    units_sold BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.product_id,
        p.product_name,
        ROUND(SUM(oi.line_total), 2) as total_revenue,
        SUM(oi.quantity) as units_sold
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    WHERE p.category_id = category_id_param
    GROUP BY p.product_id, p.product_name
    ORDER BY SUM(oi.line_total) DESC
    LIMIT limit_param;
END;
$$;

-- Test it
SELECT * FROM get_top_products_in_category(1, 5);


-- ================================================
-- Function 5: Calculate Discount Percentage
-- Purpose: Get actual discount percentage applied
-- ================================================
CREATE OR REPLACE FUNCTION get_effective_discount_pct(order_id_param INT)
RETURNS DECIMAL(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    discount_pct DECIMAL(5,2);
BEGIN
    SELECT 
        ROUND(100.0 * discount_amount / NULLIF(total_amount + discount_amount, 0), 2)
    INTO discount_pct
    FROM orders
    WHERE order_id = order_id_param;
    
    RETURN COALESCE(discount_pct, 0);
END;
$$;

-- Test it
SELECT 
    order_id,
    total_amount,
    discount_amount,
    get_effective_discount_pct(order_id) as discount_pct
FROM orders
WHERE discount_amount > 0
LIMIT 10;


-- ================================================
-- Function 6: Get Customer Purchase Frequency
-- Purpose: Calculate average days between purchases
-- ================================================
CREATE OR REPLACE FUNCTION get_purchase_frequency(customer_id_param INT)
RETURNS DECIMAL(8,2)
LANGUAGE plpgsql
AS $$
DECLARE
    avg_days DECIMAL(8,2);
BEGIN
    SELECT 
        EXTRACT(DAY FROM (MAX(order_date) - MIN(order_date))) / 
        NULLIF(COUNT(*) - 1, 0)
    INTO avg_days
    FROM orders
    WHERE customer_id = customer_id_param;
    
    RETURN COALESCE(avg_days, NULL);
END;
$$;

-- Test it
SELECT 
    customer_id,
    first_name || ' ' || last_name as name,
    get_purchase_frequency(customer_id) as avg_days_between_orders
FROM customers
WHERE customer_id IN (
    SELECT customer_id 
    FROM orders 
    GROUP BY customer_id 
    HAVING COUNT(*) > 1
)
LIMIT 10;
