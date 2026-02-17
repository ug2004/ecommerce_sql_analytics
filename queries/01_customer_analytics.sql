-- ================================================
-- CUSTOMER ANALYTICS QUERIES
-- ================================================

-- Query 1: Customer Lifetime Value (CLV)
-- Purpose: Identify most valuable customers
-- ================================================
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.segment,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.total_amount) AS lifetime_value,
    AVG(o.total_amount) AS avg_order_value,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date,
    EXTRACT(DAY FROM (MAX(o.order_date) - MIN(o.order_date))) AS customer_tenure_days
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.segment
HAVING COUNT(o.order_id) > 0
ORDER BY lifetime_value DESC
LIMIT 20;


-- ================================================
-- Query 2: RFM Analysis (Recency, Frequency, Monetary)
-- Purpose: Customer segmentation for targeted marketing
-- ================================================
WITH customer_rfm AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        CURRENT_DATE - MAX(o.order_date)::date AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.total_amount) AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
rfm_scores AS (
    SELECT 
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM customer_rfm
)
SELECT 
    customer_id,
    customer_name,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary_value,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS rfm_total,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost Customers'
        ELSE 'Potential Loyalists'
    END AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC
LIMIT 50;


-- ================================================
-- Query 3: Cohort Retention Analysis
-- Purpose: Track customer retention by signup month
-- ================================================
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', registration_date) AS cohort_month
    FROM customers
),
customer_orders AS (
    SELECT 
        o.customer_id,
        cc.cohort_month,
        DATE_TRUNC('month', o.order_date) AS order_month,
        EXTRACT(YEAR FROM AGE(o.order_date, cc.cohort_month)) * 12 + 
        EXTRACT(MONTH FROM AGE(o.order_date, cc.cohort_month)) AS months_since_signup
    FROM orders o
    JOIN customer_cohorts cc ON o.customer_id = cc.customer_id
)
SELECT 
    cohort_month,
    COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN customer_id END) AS month_0,
    COUNT(DISTINCT CASE WHEN months_since_signup = 1 THEN customer_id END) AS month_1,
    COUNT(DISTINCT CASE WHEN months_since_signup = 2 THEN customer_id END) AS month_2,
    COUNT(DISTINCT CASE WHEN months_since_signup = 3 THEN customer_id END) AS month_3,
    COUNT(DISTINCT CASE WHEN months_since_signup = 6 THEN customer_id END) AS month_6,
    COUNT(DISTINCT CASE WHEN months_since_signup = 12 THEN customer_id END) AS month_12,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 1 THEN customer_id END) / 
          NULLIF(COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN customer_id END), 0), 2) AS retention_month_1,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 3 THEN customer_id END) / 
          NULLIF(COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN customer_id END), 0), 2) AS retention_month_3
FROM customer_orders
GROUP BY cohort_month
ORDER BY cohort_month DESC;

-- ================================================
-- Query 4: Customer Churn Prediction Indicators 
-- ================================================

WITH order_gaps AS (
    SELECT
        o.customer_id,
        o.order_date,
        EXTRACT(
            DAY FROM (o.order_date - LAG(o.order_date) OVER (
                PARTITION BY o.customer_id
                ORDER BY o.order_date
            ))
        ) AS days_between_orders
    FROM orders o
),
customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.email,
        COUNT(o.order_id) AS total_orders,
        MAX(o.order_date) AS last_order_date,
        CURRENT_DATE - MAX(o.order_date)::date AS days_since_last_order,
        AVG(o.total_amount) AS avg_order_value,
        SUM(o.total_amount) AS total_spent,
        AVG(og.days_between_orders) AS avg_days_between_orders
    FROM customers c
    LEFT JOIN orders o 
        ON c.customer_id = o.customer_id
    LEFT JOIN order_gaps og 
        ON c.customer_id = og.customer_id
       AND o.order_date = og.order_date
    GROUP BY 
        c.customer_id, 
        c.first_name, 
        c.last_name, 
        c.email
)
SELECT 
    customer_id,
    customer_name,
    email,
    total_orders,
    last_order_date,
    days_since_last_order,
    ROUND(avg_order_value, 2) AS avg_order_value,
    ROUND(total_spent, 2) AS total_spent,
    ROUND(avg_days_between_orders, 0) AS avg_days_between_orders,
    CASE 
        WHEN days_since_last_order > 180 THEN 'High Risk'
        WHEN days_since_last_order > 90 THEN 'Medium Risk'
        WHEN days_since_last_order > 60 THEN 'Low Risk'
        ELSE 'Active'
    END AS churn_risk,
    CASE 
        WHEN days_since_last_order > COALESCE(avg_days_between_orders * 2, 60)
            THEN 'Overdue'
        ELSE 'On Track'
    END AS purchase_pattern
FROM customer_metrics
WHERE total_orders > 0
ORDER BY days_since_last_order DESC
LIMIT 100;


-- ================================================
-- Query 5: Customer Acquisition by Month
-- Purpose: Track customer growth over time
-- ================================================
SELECT 
    DATE_TRUNC('month', registration_date) AS signup_month,
    COUNT(*) AS new_customers,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', registration_date)) AS cumulative_customers
FROM customers
GROUP BY DATE_TRUNC('month', registration_date)
ORDER BY signup_month;


-- ================================================
-- Query 6: Top Customers by Country
-- Purpose: Geographic distribution of valuable customers
-- ================================================
SELECT 
    c.country,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    SUM(o.total_amount) AS total_revenue,
    AVG(o.total_amount) AS avg_order_value,
    COUNT(o.order_id) AS total_orders
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.country
HAVING COUNT(o.order_id) > 0
ORDER BY total_revenue DESC
LIMIT 15;
