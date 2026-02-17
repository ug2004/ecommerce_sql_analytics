-- ================================================
-- TRIGGERS
-- ================================================

-- Trigger 1: Auto-update product updated_at timestamp
-- ================================================
CREATE OR REPLACE FUNCTION update_product_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_product_timestamp
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_product_timestamp();


-- ================================================
-- Trigger 2: Update inventory after order item insert
-- ================================================
CREATE OR REPLACE FUNCTION decrease_inventory_on_order()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Decrease stock quantity in first available warehouse
    UPDATE inventory
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id
      AND stock_quantity >= NEW.quantity
      AND inventory_id = (
          SELECT inventory_id 
          FROM inventory 
          WHERE product_id = NEW.product_id 
            AND stock_quantity >= NEW.quantity
          LIMIT 1
      );
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_decrease_inventory
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION decrease_inventory_on_order();


-- ================================================
-- Trigger 3: Log low stock alerts
-- ================================================
-- First create log table
CREATE TABLE IF NOT EXISTS inventory_alerts (
    alert_id SERIAL PRIMARY KEY,
    product_id INT,
    warehouse_id INT,
    stock_quantity INT,
    reorder_level INT,
    alert_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_low_stock_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- If stock falls below or equals reorder level, log it
    IF NEW.stock_quantity <= NEW.reorder_level THEN
        INSERT INTO inventory_alerts (product_id, warehouse_id, stock_quantity, reorder_level)
        VALUES (NEW.product_id, NEW.warehouse_id, NEW.stock_quantity, NEW.reorder_level);
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_low_stock_alert
AFTER UPDATE ON inventory
FOR EACH ROW
WHEN (NEW.stock_quantity <= NEW.reorder_level)
EXECUTE FUNCTION log_low_stock_alert();


-- ================================================
-- Trigger 4: Update customer total_spent on order
-- ================================================
CREATE OR REPLACE FUNCTION update_customer_total_spent()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update customer's total spent
    UPDATE customers
    SET 
        total_spent = (
            SELECT COALESCE(SUM(total_amount), 0)
            FROM orders
            WHERE customer_id = NEW.customer_id
              AND status NOT IN ('Cancelled')
        )
    WHERE customer_id = NEW.customer_id;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_customer_spending
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_customer_total_spent();


-- ================================================
-- Trigger 5: Validate order amount before insert
-- ================================================
CREATE OR REPLACE FUNCTION validate_order_amount()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Ensure total_amount is not negative
    IF NEW.total_amount < 0 THEN
        RAISE EXCEPTION 'Order total amount cannot be negative';
    END IF;
    
    -- Ensure discount is not greater than subtotal
    IF NEW.discount_amount > NEW.total_amount + NEW.discount_amount THEN
        RAISE EXCEPTION 'Discount amount cannot exceed order subtotal';
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_validate_order
BEFORE INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION validate_order_amount();


-- ================================================
-- Trigger 6: Auto-update order updated_at
-- ================================================
CREATE OR REPLACE FUNCTION update_order_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_order_timestamp
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_order_timestamp();


-- ================================================
-- Test Triggers
-- ================================================
-- Test by updating a product
UPDATE products SET price = price WHERE product_id = 1;

-- Check if timestamp was updated
SELECT product_id, product_name, updated_at FROM products WHERE product_id = 1;

-- Check inventory alerts
SELECT * FROM inventory_alerts ORDER BY alert_date DESC LIMIT 10;
