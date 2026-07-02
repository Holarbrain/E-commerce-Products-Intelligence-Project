-- ============================================================
-- E-COMMERCE PRODUCT INTELLIGENCE — SQL ANALYSIS
-- Author  : Holarbrain | holarbrain.github.io
-- Dataset : 6 tables · ~133K rows · 2023-01-01 to 2026-06-01
-- Engine  : MySQL / DuckDB / PostgreSQL compatible
-- ============================================================


-- ============================================================
-- SCHEMA REFERENCE
-- ============================================================
--
--  users_cleaned         (user_id, age, gender, country, city,
--                         signup_date, income_level, preferred_category,
--                         loyalty_tier)
--
--  products_cleaned      (product_id, product_name, product_description,
--                         category, subcategory, brand, price,
--                         rating_avg, review_count, stock_quantity, date_added)
--
--  sessions_cleaned      (session_id, user_id, start_time, device_type,
--                         referrer_source, is_converted)
--
--  interactions_cleaned  (interaction_id, user_id, product_id, session_id,
--                         interaction_type, timestamp, dwell_time_ms)
--
--  purchases_cleaned     (purchase_id, order_id, user_id, product_id,
--                         session_id, interaction_id, quantity, unit_price,
--                         total_amount, order_date)
--
--  reviews_cleaned       (review_id, user_id, product_id, purchase_id,
--                         rating, title, review_text, review_date)
--
-- ============================================================


-- ============================================================
-- SECTION 1 · REVENUE BY CATEGORY
-- ============================================================

-- Q1.1  Revenue summary per category (all-time)
SELECT
    p.category,
    COUNT(DISTINCT pu.order_id)                                     AS total_orders,
    ROUND(SUM(pu.total_amount), 2)                                  AS total_revenue,
    ROUND(
        SUM(pu.total_amount) /
        SUM(SUM(pu.total_amount)) OVER () * 100, 2
    )                                                               AS pct_of_total_revenue,
    ROUND(AVG(pu.unit_price), 2)                                    AS avg_unit_price,
    ROUND(SUM(pu.total_amount) / COUNT(DISTINCT pu.order_id), 2)   AS revenue_per_order
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Expected results:
-- category                 | total_orders | total_revenue | pct_of_total_revenue
-- Electronics              |          236 |     40,316.42 |                31.13
-- Sports & Outdoors        |          201 |     21,000.52 |                16.22
-- Home & Kitchen           |          212 |     17,712.88 |                13.68
-- Clothing & Accessories   |          264 |     15,202.68 |                11.74
-- Automotive               |          121 |     10,656.95 |                 8.23
-- Books                    |          131 |      6,864.55 |                 5.30
-- Office Products          |           86 |      5,638.30 |                 4.35
-- Beauty & Personal Care   |          139 |      5,571.39 |                 4.30
-- Toys & Games             |           90 |      4,292.40 |                 3.31
-- Grocery & Gourmet        |           98 |      2,254.76 |                 1.74


-- Q1.2  Subcategory drill-down — top 10 by revenue
SELECT
    p.category,
    p.subcategory,
    COUNT(DISTINCT pu.order_id)         AS orders,
    ROUND(SUM(pu.total_amount), 2)      AS revenue,
    ROUND(AVG(pu.unit_price), 2)        AS avg_price
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY p.category, p.subcategory
ORDER BY revenue DESC
LIMIT 10;


-- Q1.3  Monthly revenue trend by category (year-month rollup)
SELECT
    DATE_FORMAT(pu.order_date, '%Y-%m')     AS yr_month,   -- MySQL
    -- TO_CHAR(pu.order_date, 'YYYY-MM')    AS yr_month,   -- PostgreSQL / DuckDB
    p.category,
    ROUND(SUM(pu.total_amount), 2)          AS monthly_revenue
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY yr_month, p.category
ORDER BY yr_month, monthly_revenue DESC;


-- Q1.4  Year-over-year revenue growth by category
SELECT
    p.category,
    YEAR(pu.order_date)                         AS yr,     -- MySQL
    -- EXTRACT(YEAR FROM pu.order_date)         AS yr,     -- PostgreSQL / DuckDB
    ROUND(SUM(pu.total_amount), 2)              AS revenue,
    ROUND(
        (SUM(pu.total_amount) -
         LAG(SUM(pu.total_amount)) OVER (
             PARTITION BY p.category
             ORDER BY YEAR(pu.order_date)
         )) /
        LAG(SUM(pu.total_amount)) OVER (
             PARTITION BY p.category
             ORDER BY YEAR(pu.order_date)
        ) * 100, 2
    )                                            AS yoy_growth_pct
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY p.category, YEAR(pu.order_date)
ORDER BY p.category, yr;


-- ============================================================
-- SECTION 2 · TOP PRODUCTS
-- ============================================================

-- Q2.1  Top 15 products by total revenue (with ratings)
SELECT
    p.product_name,
    p.category,
    p.brand,
    ROUND(p.price, 2)                          AS list_price,
    COUNT(DISTINCT pu.order_id)                AS times_ordered,
    SUM(pu.quantity)                           AS units_sold,
    ROUND(SUM(pu.total_amount), 2)             AS total_revenue,
    ROUND(AVG(p.rating_avg), 2)                AS avg_rating,
    ROUND(
        SUM(pu.total_amount) /
        SUM(SUM(pu.total_amount)) OVER () * 100, 2
    )                                          AS pct_of_total_revenue
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY
    p.product_name, p.category, p.brand, p.price
ORDER BY total_revenue DESC
LIMIT 15;

-- Expected top 5:
-- product_name                       | revenue    | rating
-- Apple Book4 Ultrabook              |  7,202.93  |  3.90
-- Apple Accessorie Stand             |  6,140.92  |  4.10
-- Wilson Book19 Fitness Equipment    |  5,883.08  |  4.30
-- Instant Pot Microfiber Kitchenware |  5,218.45  |  4.20
-- Wilson Fitness Equipment Pro       |  3,471.85  |  3.90


-- Q2.2  Top products by order frequency (most-purchased)
SELECT
    p.product_name,
    p.category,
    p.brand,
    COUNT(DISTINCT pu.order_id)          AS total_orders,
    SUM(pu.quantity)                     AS total_units,
    ROUND(SUM(pu.total_amount), 2)       AS total_revenue,
    ROUND(AVG(pu.unit_price), 2)         AS avg_sale_price,
    ROUND(p.price, 2)                    AS list_price
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY p.product_name, p.category, p.brand, p.price
ORDER BY total_orders DESC
LIMIT 10;


-- Q2.3  Top brands by revenue
SELECT
    p.brand,
    COUNT(DISTINCT p.product_id)         AS products_in_catalog,
    COUNT(DISTINCT pu.order_id)          AS total_orders,
    ROUND(SUM(pu.total_amount), 2)       AS total_revenue,
    ROUND(AVG(pu.unit_price), 2)         AS avg_sale_price,
    ROUND(AVG(p.rating_avg), 2)          AS avg_product_rating
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY p.brand
ORDER BY total_revenue DESC
LIMIT 15;


-- Q2.4  High-rated products not yet generating revenue (missed opportunities)
SELECT
    p.product_name,
    p.category,
    p.brand,
    ROUND(p.price, 2)       AS price,
    ROUND(p.rating_avg, 2)  AS rating,
    p.review_count,
    p.stock_quantity
FROM products_cleaned p
LEFT JOIN purchases_cleaned pu ON p.product_id = pu.product_id
WHERE pu.product_id IS NULL          -- no purchases yet
  AND p.rating_avg >= 4.0            -- but well-rated (via reviews or catalog)
  AND p.stock_quantity > 0           -- and in stock
ORDER BY p.rating_avg DESC, p.price DESC
LIMIT 10;


-- Q2.5  Revenue rank within each category (window function)
SELECT
    p.category,
    p.product_name,
    p.brand,
    ROUND(SUM(pu.total_amount), 2)                        AS revenue,
    RANK() OVER (
        PARTITION BY p.category
        ORDER BY SUM(pu.total_amount) DESC
    )                                                      AS rank_in_category
FROM purchases_cleaned pu
JOIN products_cleaned p ON pu.product_id = p.product_id
GROUP BY p.category, p.product_name, p.brand
ORDER BY p.category, rank_in_category;


-- ============================================================
-- SECTION 3 · CONVERSION RATE BY REFERRER SOURCE
-- ============================================================

-- Q3.1  Session conversion rate by referrer source
SELECT
    referrer_source,
    COUNT(session_id)                                            AS total_sessions,
    COUNT(DISTINCT user_id)                                      AS unique_users,
    SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)        AS converted_sessions,
    ROUND(
        SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)
        * 100.0 / COUNT(session_id), 2
    )                                                            AS conversion_rate_pct
FROM sessions_cleaned
GROUP BY referrer_source
ORDER BY conversion_rate_pct DESC;

-- Expected results:
-- referrer_source  | sessions | converted | conv_rate_pct
-- display_ad       |      385 |        31 |          8.05
-- paid_search      |    1,509 |       121 |          8.02
-- email            |    1,888 |       144 |          7.63
-- referral         |    1,008 |        75 |          7.44
-- direct           |    4,742 |       351 |          7.40
-- organic_search   |    6,950 |       513 |          7.38
-- social_media     |    2,833 |       205 |          7.24


-- Q3.2  Revenue generated per referrer source (session → purchase join)
SELECT
    s.referrer_source,
    COUNT(DISTINCT s.session_id)                                  AS total_sessions,
    COUNT(DISTINCT pu.order_id)                                   AS orders,
    ROUND(SUM(pu.total_amount), 2)                                AS total_revenue,
    ROUND(AVG(pu.total_amount), 2)                                AS avg_order_value,
    ROUND(
        COUNT(DISTINCT pu.order_id) * 100.0 /
        COUNT(DISTINCT s.session_id), 2
    )                                                             AS order_conversion_pct
FROM sessions_cleaned s
LEFT JOIN purchases_cleaned pu ON s.session_id = pu.session_id
GROUP BY s.referrer_source
ORDER BY total_revenue DESC;

-- Key insight: organic_search generates the most revenue ($45,729)
-- despite lower conversion rate — driven by its large session volume (36%).


-- Q3.3  Conversion rate by device type
SELECT
    device_type,
    COUNT(session_id)                                               AS total_sessions,
    SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)           AS converted,
    ROUND(
        SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)
        * 100.0 / COUNT(session_id), 2
    )                                                               AS conversion_rate_pct
FROM sessions_cleaned
GROUP BY device_type
ORDER BY conversion_rate_pct DESC;


-- Q3.4  Cross-tab: conversion rate by device × referrer
SELECT
    device_type,
    referrer_source,
    COUNT(session_id)                                               AS sessions,
    SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)           AS conversions,
    ROUND(
        SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)
        * 100.0 / COUNT(session_id), 2
    )                                                               AS conv_rate_pct
FROM sessions_cleaned
GROUP BY device_type, referrer_source
ORDER BY conv_rate_pct DESC
LIMIT 12;

-- Top combination: tablet + paid_search = 11.88% conversion rate


-- Q3.5  Referrer source: sessions vs revenue share (efficiency view)
SELECT
    s.referrer_source,
    ROUND(COUNT(DISTINCT s.session_id) * 100.0 /
          SUM(COUNT(DISTINCT s.session_id)) OVER (), 2)   AS session_share_pct,
    ROUND(SUM(pu.total_amount) * 100.0 /
          SUM(SUM(pu.total_amount)) OVER (), 2)           AS revenue_share_pct,
    ROUND(
        SUM(pu.total_amount) * 100.0 /
        SUM(SUM(pu.total_amount)) OVER ()
        -
        COUNT(DISTINCT s.session_id) * 100.0 /
        SUM(COUNT(DISTINCT s.session_id)) OVER ()
    , 2)                                                   AS efficiency_delta
FROM sessions_cleaned s
LEFT JOIN purchases_cleaned pu ON s.session_id = pu.session_id
GROUP BY s.referrer_source
ORDER BY efficiency_delta DESC;

-- Positive efficiency_delta = channel punches above its weight (more revenue than traffic share)
-- display_ad: smallest traffic share, highest revenue-per-session


-- ============================================================
-- SECTION 4 · BONUS QUERIES
-- ============================================================

-- Q4.1  Customer lifetime value (CLV) by loyalty tier
SELECT
    u.loyalty_tier,
    COUNT(DISTINCT u.user_id)            AS total_customers,
    COUNT(DISTINCT pu.order_id)          AS total_orders,
    ROUND(SUM(pu.total_amount), 2)       AS total_revenue,
    ROUND(AVG(pu.total_amount), 2)       AS avg_spend_per_transaction,
    ROUND(
        SUM(pu.total_amount) /
        COUNT(DISTINCT u.user_id), 2
    )                                    AS revenue_per_customer
FROM users_cleaned u
LEFT JOIN purchases_cleaned pu ON u.user_id = pu.user_id
GROUP BY u.loyalty_tier
ORDER BY revenue_per_customer DESC;


-- Q4.2  Full funnel: registered → session → interaction → purchase → review
SELECT
    'Registered users'          AS funnel_stage,
    COUNT(DISTINCT user_id)     AS user_count
FROM users_cleaned
UNION ALL
SELECT 'Had a session',        COUNT(DISTINCT user_id) FROM sessions_cleaned
UNION ALL
SELECT 'Interacted (view/click)', COUNT(DISTINCT user_id) FROM interactions_cleaned
UNION ALL
SELECT 'Purchased',            COUNT(DISTINCT user_id) FROM purchases_cleaned
UNION ALL
SELECT 'Left a review',        COUNT(DISTINCT user_id) FROM reviews_cleaned;


-- Q4.3  Products with the highest interaction-to-purchase ratio
SELECT
    p.product_name,
    p.category,
    COUNT(DISTINCT i.interaction_id)     AS total_interactions,
    COUNT(DISTINCT pu.purchase_id)       AS total_purchases,
    ROUND(
        COUNT(DISTINCT pu.purchase_id) * 100.0 /
        NULLIF(COUNT(DISTINCT i.interaction_id), 0), 2
    )                                    AS purchase_rate_pct
FROM products_cleaned p
JOIN interactions_cleaned i  ON p.product_id = i.product_id
LEFT JOIN purchases_cleaned pu ON p.product_id = pu.product_id
GROUP BY p.product_name, p.category
HAVING COUNT(DISTINCT i.interaction_id) >= 10   -- minimum interaction threshold
ORDER BY purchase_rate_pct DESC
LIMIT 10;


-- Q4.4  Revenue by customer income level
SELECT
    u.income_level,
    COUNT(DISTINCT u.user_id)            AS customers,
    COUNT(DISTINCT pu.order_id)          AS orders,
    ROUND(SUM(pu.total_amount), 2)       AS total_revenue,
    ROUND(AVG(pu.total_amount), 2)       AS avg_spend
FROM users_cleaned u
JOIN purchases_cleaned pu ON u.user_id = pu.user_id
GROUP BY u.income_level
ORDER BY avg_spend DESC;


-- Q4.5  Review sentiment proxy — avg rating by category
SELECT
    p.category,
    COUNT(r.review_id)                   AS total_reviews,
    ROUND(AVG(r.rating), 2)              AS avg_rating,
    SUM(CASE WHEN r.rating >= 4 THEN 1 ELSE 0 END)  AS positive_reviews,
    ROUND(
        SUM(CASE WHEN r.rating >= 4 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(r.review_id), 1
    )                                    AS positive_rate_pct
FROM reviews_cleaned r
JOIN products_cleaned p ON r.product_id = p.product_id
GROUP BY p.category
ORDER BY avg_rating DESC;


-- ============================================================
-- END OF FILE
-- ============================================================
