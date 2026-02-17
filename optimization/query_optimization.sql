-- ================================================
-- QUERY OPTIMIZATION EXAMPLES
-- ================================================

-- Example 1: Using EXPLAIN ANALYZE
-- ================================================
-- Check query execution plan
EXPLAIN ANALYZE
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC
LIMIT 100;


-- ================================================
-- Example 2: Index Usage Check
-- ================================================
-- Check if indexes are being used
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;


-- ================================================
-- Example 3: Table Statistics
-- ================================================
-- Analyze table statistics for query planner
ANALYZE customers;
ANALYZE orders;
ANALYZE products;
ANALYZE order_items;

-- View table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;


-- ================================================
-- Example 4: Find Slow Queries (requires pg_stat_statements extension)
-- ================================================
-- Enable extension (run once)
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- View slow queries
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;


-- ================================================
-- Example 5: Vacuum and Analyze
-- ================================================
-- Reclaim space and update statistics
VACUUM ANALYZE customers;
VACUUM ANALYZE orders;
VACUUM ANALYZE products;
VACUUM ANALYZE order_items;
