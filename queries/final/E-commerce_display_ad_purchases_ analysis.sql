-- ============================================================
-- DISPLAY AD SESSION PURCHASE ANALYSIS
-- Author  : Holarbrain | holarbrain.github.io
-- Dataset : sessions_cleaned + purchases_cleaned + products_cleaned + users_cleaned
-- Engine  : MySQL / DuckDB / PostgreSQL compatible
-- Purpose : Identify which products are most purchased through
--           display_ad sessions — the highest-converting channel
-- ============================================================


-- ============================================================
-- QUERY 1 · Display Ad Session Overview
-- How many display ad sessions exist, and how many converted?
-- ============================================================

SELECT
    COUNT(*)                                                AS total_display_ad_sessions,
    COUNT(DISTINCT user_id)                                 AS unique_users,
    SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)   AS converted_sessions,
    ROUND(
        SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                       AS conversion_rate_pct
FROM sessions_cleaned
WHERE referrer_source = 'display_ad';

-- Results:
-- total_sessions | unique_users | converted | conv_rate_pct
--            385 |          366 |        31 |          8.05


-- ============================================================
-- QUERY 2 · Top Products Purchased via Display Ad Sessions
-- Core join: sessions → purchases → products
-- ============================================================

SELECT
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    ROUND(p.price, 2)                           AS list_price,
    COUNT(DISTINCT pu.order_id)                 AS orders,
    SUM(pu.quantity)                            AS units_sold,
    ROUND(SUM(pu.total_amount), 2)              AS total_revenue,
    ROUND(AVG(pu.unit_price), 2)                AS avg_sale_price,
    ROUND(p.rating_avg, 2)                      AS avg_rating
FROM sessions_cleaned    s
JOIN purchases_cleaned  pu ON s.session_id  = pu.session_id
JOIN products_cleaned    p ON pu.product_id = p.product_id
WHERE s.referrer_source = 'display_ad'
GROUP BY
    p.product_name, p.category, p.subcategory,
    p.brand, p.price, p.rating_avg
ORDER BY total_revenue DESC
LIMIT 15;

-- Top 5 results:
-- product_name                  | category    | revenue  | orders
-- Apple Book4 Ultrabook         | Electronics | 514.66   |  2
-- Samsung X9 Fitness Tracker    | Electronics | 268.44   |  1
-- Castrol Prime7 Electronic     | Automotive  | 245.26   |  1
-- NOCO Car Care Kit             | Automotive  | 172.29   |  1
-- Bosch Tools & Equipment Set   | Automotive  | 154.28   |  2


-- ============================================================
-- QUERY 3 · Category Revenue from Display Ad Sessions
-- Which categories benefit most from display advertising?
-- ============================================================

SELECT
    p.category,
    COUNT(DISTINCT pu.order_id)                             AS orders,
    SUM(pu.quantity)                                        AS units_sold,
    ROUND(SUM(pu.total_amount), 2)                          AS total_revenue,
    ROUND(
        SUM(pu.total_amount) * 100.0 /
        SUM(SUM(pu.total_amount)) OVER (), 2
    )                                                       AS pct_of_display_revenue
FROM sessions_cleaned    s
JOIN purchases_cleaned  pu ON s.session_id  = pu.session_id
JOIN products_cleaned    p ON pu.product_id = p.product_id
WHERE s.referrer_source = 'display_ad'
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Results:
-- category                 | orders | revenue   | pct_of_display_revenue
-- Electronics              |      5 | 963.10    |  27.07%
-- Automotive               |      7 | 675.46    |  18.99%
-- Home & Kitchen           |      5 | 541.33    |  15.22%
-- Sports & Outdoors        |      3 | 505.27    |  14.20%
-- Clothing & Accessories   |      6 | 384.57    |  10.81%
-- Books                    |      3 | 281.14    |   7.90%
-- Grocery & Gourmet        |      3 | 111.41    |   3.13%
-- Office Products          |      1 |  68.49    |   1.93%
-- Toys & Games             |      1 |  26.63    |   0.75%


-- ============================================================
-- QUERY 4 · Display Ad Revenue Share per Product
-- CTE comparison: how much of a product's total revenue
-- came specifically from display ad sessions?
-- ============================================================

WITH display_revenue AS (
    SELECT
        pu.product_id,
        COUNT(DISTINCT pu.order_id)         AS display_orders,
        ROUND(SUM(pu.total_amount), 2)      AS display_revenue
    FROM sessions_cleaned    s
    JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
    WHERE s.referrer_source = 'display_ad'
    GROUP BY pu.product_id
),
all_channel_revenue AS (
    SELECT
        product_id,
        COUNT(DISTINCT order_id)            AS total_orders,
        ROUND(SUM(total_amount), 2)         AS total_revenue
    FROM purchases_cleaned
    GROUP BY product_id
)
SELECT
    p.product_name,
    p.category,
    p.brand,
    d.display_orders,
    d.display_revenue,
    a.total_orders,
    a.total_revenue,
    ROUND(d.display_revenue * 100.0 / a.total_revenue, 1)  AS display_pct_of_product_rev
FROM display_revenue        d
JOIN all_channel_revenue    a ON d.product_id  = a.product_id
JOIN products_cleaned               p ON d.product_id  = p.product_id
ORDER BY d.display_revenue DESC
LIMIT 10;

-- Key findings:
-- Zwilling Furniture - Gray      → 100.0% of its revenue came from display ads
-- Apple Prime16 Instant Camera   → 100.0%
-- Wilson Premium Outdoor Recr.   → 49.5%
-- NOCO Car Care Kit              → 16.0%
-- Samsung X9 Fitness Tracker     → 14.9%


-- ============================================================
-- QUERY 5 · Display Ad vs All Channels — Product Comparison
-- Side-by-side revenue and conversion for the same products
-- across display ads vs every other referrer source
-- ============================================================

WITH display_stats AS (
    SELECT
        pu.product_id,
        COUNT(DISTINCT pu.order_id)         AS display_orders,
        ROUND(SUM(pu.total_amount), 2)      AS display_revenue,
        ROUND(AVG(pu.unit_price), 2)        AS display_avg_price
    FROM sessions_cleaned    s
    JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
    WHERE s.referrer_source = 'display_ad'
    GROUP BY pu.product_id
),
other_stats AS (
    SELECT
        pu.product_id,
        COUNT(DISTINCT pu.order_id)         AS other_orders,
        ROUND(SUM(pu.total_amount), 2)      AS other_revenue,
        ROUND(AVG(pu.unit_price), 2)        AS other_avg_price
    FROM sessions_cleaned    s
    JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
    WHERE s.referrer_source != 'display_ad'
    GROUP BY pu.product_id
)
SELECT
    p.product_name,
    p.category,
    d.display_orders,
    d.display_revenue,
    d.display_avg_price,
    o.other_orders,
    o.other_revenue,
    o.other_avg_price
FROM display_stats   d
JOIN other_stats     o ON d.product_id  = o.product_id
JOIN products_cleaned        p ON d.product_id  = p.product_id
ORDER BY d.display_revenue DESC
LIMIT 10;


-- ============================================================
-- QUERY 6 · Buyer Profile — Display Ad Purchasers
-- Who is actually buying from display ad sessions?
-- ============================================================

SELECT
    u.loyalty_tier,
    u.income_level,
    u.gender,
    COUNT(DISTINCT pu.user_id)              AS buyers,
    ROUND(AVG(u.age), 1)                   AS avg_age,
    ROUND(SUM(pu.total_amount), 2)         AS total_revenue,
    ROUND(AVG(pu.total_amount), 2)         AS avg_spend_per_txn
FROM sessions_cleaned    s
JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
JOIN users_cleaned       u ON pu.user_id   = u.user_id
WHERE s.referrer_source = 'display_ad'
GROUP BY u.loyalty_tier, u.income_level, u.gender
ORDER BY total_revenue DESC;

-- Key insight:
-- Bronze + High income + Female → highest revenue segment ($693.55)
-- very_high income buyers → highest avg spend per transaction ($208.77)
-- Most display ad buyers are Bronze tier (high acquisition, low retention yet)


-- ============================================================
-- QUERY 7 · Time-Based: Display Ad Purchases by Month
-- Are display ad conversions growing over time?
-- ============================================================

SELECT
    DATE_FORMAT(pu.order_date, '%Y-%m')                 AS yr_month,   -- MySQL
    -- TO_CHAR(pu.order_date, 'YYYY-MM')               AS yr_month,   -- PostgreSQL / DuckDB
    COUNT(DISTINCT pu.order_id)                         AS orders,
    ROUND(SUM(pu.total_amount), 2)                      AS revenue
FROM sessions_cleaned    s
JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
WHERE s.referrer_source = 'display_ad'
GROUP BY yr_month
ORDER BY yr_month;


-- ============================================================
-- SUMMARY OF FINDINGS
-- ============================================================
--
--  · Display ads are the HIGHEST CONVERTING channel at 8.05%
--    (vs 7.24% for social media, the lowest)
--
--  · 385 display ad sessions → 31 conversions → 42 purchase rows
--    (some orders contain multiple products)
--
--  · Electronics leads category revenue ($963 / 27% of display spend)
--    driven by Apple Book4 Ultrabook and Samsung X9 Fitness Tracker
--
--  · Automotive is #2 despite lower avg price — higher order volume (7 orders)
--
--  · 2 products (Zwilling Furniture, Apple Prime16 Camera) get 100% of
--    their total revenue exclusively from display ad sessions
--
--  · Buyer profile: predominantly Bronze loyalty tier, high/very_high
--    income, avg age 35–44 — suggests display ads attract new, affluent users
--
-- ============================================================
-- END OF FILE
-- ============================================================
