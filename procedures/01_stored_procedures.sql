-- ================================================
-- STORED PROCEDURES
-- ================================================

-- Procedure 1: Update Customer Segmentation
-- Purpose: Automatically categorize customers based on spending
-- ================================================
CREATE OR REPLACE PROCEDURE update_customer_segments()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update customer segments based on total spending
    UPDATE customers c
    SET 
        segment = CASE
            WHEN spend.total_spent >= 5000 THEN 'VIP'
            WHEN spend.total_spent >= 2000 THEN 'Premium'
            WHEN spend.total_spent >= 500 THEN 'Regular'
            ELSE 'New'
        END,
        total_spent = spend.total_spent
    FROM (
        SELECT 
            customer_id,
            COALESCE(SUM(total_amount), 0) AS total_spent
        FROM orders
        WHERE status NOT IN ('Cancelled')
        GROUP BY customer_id
    ) spend
    WHERE c.customer_id = spend.customer_id;
    
    RAISE NOTICE 'Customer segments updated successfully';
END;
$$;

-- Test it
CALL update_customer_segments();


-- ================================================
-- Procedure 2: Generate Monthly Sales Report
-- Purpose: Create summary statistics for a given month
-- ================================================
CREATE OR REPLACE PROCEDURE generate_monthly_report(
    report_year INT,
    report_month INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_revenue DECIMAL(12,2);
    total_orders INT;
    avg_order_value DECIMAL(10,2);
    unique_customers INT;
BEGIN
    -- Calculate metrics
    SELECT 
        COALESCE(SUM(total_amount), 0),
        COUNT(*),
        COALESCE(AVG(total_amount), 0),
        COUNT(DISTINCT customer_id)
    INTO 
        total_revenue,
        total_orders,
        avg_order_value,
        unique_customers
    FROM orders
    WHERE EXTRACT(YEAR FROM order_date) = report_year
      AND EXTRACT(MONTH FROM order_date) = report_month;
    
    -- Display results
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Monthly Report: %-% ', report_year, report_month;
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total Revenue: $%', total_revenue;
    RAISE NOTICE 'Total Orders: %', total_orders;
    RAISE NOTICE 'Average Order Value: $%', avg_order_value;
    RAISE NOTICE 'Unique Customers: %', unique_customers;
    RAISE NOTICE '========================================';
END;
$$;

-- Test it (adjust year/month to match your data)
CALL generate_monthly_report(2024, 12);


-- ================================================
-- Procedure 3: Process Low Stock Alerts
-- Purpose: Identify and flag products needing reorder
-- ================================================
CREATE OR REPLACE PROCEDURE process_low_stock_alerts()
LANGUAGE plpgsql
AS $$
DECLARE
    low_stock_count INT;
    rec RECORD;
BEGIN
    -- Count low stock items
    SELECT COUNT(*)
    INTO low_stock_count
    FROM inventory
    WHERE stock_quantity <= reorder_level;
    
    RAISE NOTICE 'Low Stock Alert: % products need reordering', low_stock_count;
    
    -- Display details
    RAISE NOTICE '========================================';
    FOR rec IN (
        SELECT 
            p.product_name,
            i.stock_quantity,
            i.reorder_level,
            w.warehouse_name
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        JOIN warehouses w ON i.warehouse_id = w.warehouse_id
        WHERE i.stock_quantity <= i.reorder_level
        ORDER BY i.stock_quantity ASC
        LIMIT 10
    ) LOOP
        RAISE NOTICE 'Product: % | Stock: % | Reorder Level: % | Warehouse: %',
            rec.product_name, rec.stock_quantity, rec.reorder_level, rec.warehouse_name;
    END LOOP;
END;
$$;

-- Test it
CALL process_low_stock_alerts();


-- ================================================
-- Procedure 4: Archive Old Orders
-- Purpose: Move completed orders older than 2 years to archive
-- ================================================
-- First create archive table
CREATE TABLE IF NOT EXISTS orders_archive (
    LIKE orders INCLUDING ALL
);

CREATE OR REPLACE PROCEDURE archive_old_orders()
LANGUAGE plpgsql
AS $$
DECLARE
    archived_count INT;
BEGIN
    -- Insert into archive
    INSERT INTO orders_archive
    SELECT * FROM orders
    WHERE order_date < CURRENT_DATE - INTERVAL '2 years'
      AND status = 'Delivered';
    
    GET DIAGNOSTICS archived_count = ROW_COUNT;
    
    -- Delete from main table
    DELETE FROM orders
    WHERE order_date < CURRENT_DATE - INTERVAL '2 years'
      AND status = 'Delivered';
    
    RAISE NOTICE 'Archived % orders', archived_count;
END;
$$;


-- ================================================
-- Procedure 5: Calculate Customer Lifetime Value
-- Purpose: Update customer metrics
-- ================================================
CREATE OR REPLACE PROCEDURE calculate_customer_metrics()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Create or update customer metrics in a temp table or update existing columns
    UPDATE customers c
    SET 
        total_spent = COALESCE(metrics.total_spent, 0)
    FROM (
        SELECT 
            customer_id,
            SUM(total_amount) as total_spent
        FROM orders
        WHERE status NOT IN ('Cancelled')
        GROUP BY customer_id
    ) metrics
    WHERE c.customer_id = metrics.customer_id;
    
    RAISE NOTICE 'Customer metrics updated';
END;
$$;

-- Test it
CALL calculate_customer_metrics();
