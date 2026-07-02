-- ============================================================
-- ORGANIC SEARCH CATEGORY PURCHASE ANALYSIS
-- Author  : Holarbrain | holarbrain.github.io
-- Dataset : sessions_cleaned + purchases_cleaned + products_cleaned + users_cleaned
-- Engine  : MySQL / DuckDB / PostgreSQL compatible
-- Purpose : Identify which product categories and products are
--           most purchased through organic_search sessions
-- ============================================================
--
-- Context:
--   organic_search is the highest-volume channel (6,950 sessions,
--   36% of all traffic) and the single largest revenue contributor
--   ($45,729 out of $129,511 total — 35.3% of all revenue).
--   This script unpacks where that revenue flows by category,
--   subcategory, product, and buyer profile.
-- ============================================================


-- ============================================================
-- QUERY 1 · Organic Search Session Snapshot
-- Baseline: how large is this channel?
-- ============================================================

SELECT
    COUNT(*)                                                    AS total_sessions,
    COUNT(DISTINCT user_id)                                     AS unique_users,
    SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)       AS converted_sessions,
    ROUND(
        SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                           AS conversion_rate_pct
FROM sessions_cleaned
WHERE referrer_source = 'organic_search';

-- Result:
-- total_sessions | unique_users | converted | conv_rate_pct
--          6,950 |        4,312 |       513 |          7.38


-- ============================================================
-- QUERY 2 · Revenue by Category — Organic Search
-- Core query: which categories does organic search drive?
-- ============================================================

SELECT
    p.category,
    COUNT(DISTINCT pu.order_id)                                     AS orders,
    COUNT(DISTINCT pu.user_id)                                      AS unique_buyers,
    SUM(pu.quantity)                                                AS units_sold,
    ROUND(SUM(pu.total_amount), 2)                                  AS revenue,
    ROUND(
        SUM(pu.total_amount) * 100.0 /
        SUM(SUM(pu.total_amount)) OVER (), 2
    )                                                               AS pct_of_organic_revenue,
    ROUND(AVG(pu.unit_price), 2)                                    AS avg_unit_price,
    ROUND(SUM(pu.total_amount) / COUNT(DISTINCT pu.order_id), 2)   AS revenue_per_order
FROM sessions_cleaned
JOIN purchases_cleaned  pu ON s.session_id  = pu.session_id
JOIN products_cleaned    p ON pu.product_id = p.product_id
WHERE s.referrer_source = 'organic_search'
GROUP BY p.category
ORDER BY revenue DESC;

-- Results:
-- category                 | orders | revenue   | pct_organic | avg_price | rev/order
-- Electronics              |     77 | 13,009.63 |      28.45% |   $152.04 |   $168.96
-- Home & Kitchen           |     81 |  7,734.93 |      16.91% |    $61.69 |    $95.49
-- Sports & Outdoors        |     72 |  6,858.61 |      15.00% |    $69.13 |    $95.26
-- Clothing & Accessories   |    105 |  5,827.52 |      12.74% |    $38.06 |    $55.50
-- Automotive               |     43 |  3,788.22 |       8.28% |    $69.02 |    $88.10
-- Office Products          |     35 |  2,222.16 |       4.86% |    $40.05 |    $63.49
-- Books                    |     40 |  2,035.60 |       4.45% |    $27.80 |    $50.89
-- Beauty & Personal Care   |     44 |  1,950.26 |       4.26% |    $27.56 |    $44.32
-- Toys & Games             |     28 |  1,427.58 |       3.12% |    $43.66 |    $50.99
-- Grocery & Gourmet        |     40 |    874.43 |       1.91% |    $10.32 |    $21.86


-- ============================================================
-- QUERY 3 · Organic vs All Channels — Category Share Comparison
-- Does organic over- or under-index for each category?
-- efficiency_delta > 0 = organic punches above weight
-- ============================================================

WITH organic_stats AS (
    SELECT
        p.category,
        ROUND(SUM(pu.total_amount), 2)      AS organic_revenue,
        COUNT(DISTINCT pu.order_id)         AS organic_orders
    FROM sessions_cleaned    s
    JOIN purchases_cleaned  pu ON s.session_id  = pu.session_id
    JOIN products_cleaned    p ON pu.product_id = p.product_id
    WHERE s.referrer_source = 'organic_search'
    GROUP BY p.category
),
all_channel_stats AS (
    SELECT
        p.category,
        ROUND(SUM(pu.total_amount), 2)      AS total_revenue,
        COUNT(DISTINCT pu.order_id)         AS total_orders
    FROM purchases_cleaned pu
    JOIN products_cleaned  p ON pu.product_id = p.product_id
    GROUP BY p.category
)
SELECT
    a.category,
    o.organic_revenue,
    ROUND(o.organic_revenue * 100.0 /
          SUM(o.organic_revenue) OVER (), 2)                    AS organic_share_pct,
    a.total_revenue,
    ROUND(a.total_revenue * 100.0 /
          SUM(a.total_revenue) OVER (), 2)                      AS overall_share_pct,
    ROUND(o.organic_revenue * 100.0 / a.total_revenue, 1)      AS organic_of_category_pct,
    ROUND(
        (o.organic_revenue * 100.0 / SUM(o.organic_revenue) OVER ())
        -
        (a.total_revenue   * 100.0 / SUM(a.total_revenue)   OVER ())
    , 2)                                                        AS efficiency_delta
FROM organic_stats     o
JOIN all_channel_stats a ON o.category = a.category
ORDER BY o.organic_revenue DESC;

-- Key insight:
--   Home & Kitchen:  organic_share 16.91% vs overall 13.68% → +3.23 delta (over-indexing)
--   Office Products: organic_share  4.86% vs overall  4.35% → +0.51 delta (slight over-index)
--   Electronics:     organic_share 28.45% vs overall 31.13% → -2.68 delta (under-indexing)
--   → Home & Kitchen and Office Products respond especially well to organic search intent


-- ============================================================
-- QUERY 4 · Top Subcategories — Organic Search
-- Drill one level deeper within each category
-- ============================================================

SELECT
    p.category,
    p.subcategory,
    COUNT(DISTINCT pu.order_id)             AS orders,
    SUM(pu.quantity)                        AS units_sold,
    ROUND(SUM(pu.total_amount), 2)          AS revenue,
    ROUND(AVG(pu.unit_price), 2)            AS avg_unit_price
FROM sessions    s
JOIN purchases_cleaned  pu ON s.session_id  = pu.session_id
JOIN products_cleaned    p ON pu.product_id = p.product_id
WHERE s.referrer_source = 'organic_search'
GROUP BY p.category, p.subcategory
ORDER BY revenue DESC
LIMIT 12;

-- Top subcategories:
-- category             | subcategory        | orders | revenue
-- Electronics          | Laptops            |     22 | 4,837.77
-- Sports & Outdoors    | Fitness Equipment  |     44 | 3,571.43
-- Clothing             | Womenswear         |     38 | 2,901.58
-- Electronics          | Accessories        |     31 | 2,839.30
-- Home & Kitchen       | Kitchenware        |     32 | 2,599.35
-- Electronics          | Smartphones        |     11 | 2,264.69
-- Home & Kitchen       | Bedding            |      7 | 2,246.71
-- Automotive           | Tools & Equipment  |     20 | 1,794.37


-- ============================================================
-- QUERY 5 · Top 15 Products — Organic Search
-- Which individual products are organic search buyers choosing?
-- ============================================================

SELECT
    p.product_name,
    p.category,
    p.brand,
    COUNT(DISTINCT pu.order_id)             AS orders,
    SUM(pu.quantity)                        AS units_sold,
    ROUND(SUM(pu.total_amount), 2)          AS revenue,
    ROUND(AVG(pu.unit_price), 2)            AS avg_sale_price,
    ROUND(p.rating_avg, 2)                  AS avg_rating
FROM sessions_cleaned    s
JOIN purchases_cleaned  pu ON s.session_id  = pu.session_id
JOIN products_cleaned    p ON pu.product_id = p.product_id
WHERE s.referrer_source = 'organic_search'
GROUP BY p.product_name, p.category, p.brand, p.rating_avg
ORDER BY revenue DESC
LIMIT 15;

-- Top 5:
-- Apple Book4 Ultrabook           | Electronics        | $3,339.84 | 13 orders
-- KitchenAid Comfort Bedding      | Home & Kitchen     | $1,921.95 |  3 orders
-- Apple Accessorie Stand          | Electronics        | $1,807.40 | 25 orders
-- Wilson Book19 Fitness Equipment | Sports & Outdoors  | $1,794.13 | 13 orders
-- Instant Pot Microfiber Kitchenware | Home & Kitchen  | $1,603.16 | 15 orders


-- ============================================================
-- QUERY 6 · Organic Search Revenue Share per Product
-- CTE: what % of each product's total revenue came from organic?
-- ============================================================

WITH organic_product AS (
    SELECT
        pu.product_id,
        COUNT(DISTINCT pu.order_id)         AS organic_orders,
        ROUND(SUM(pu.total_amount), 2)      AS organic_revenue
    FROM sessions_cleaned    s
    JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
    WHERE s.referrer_source = 'organic_search'
    GROUP BY pu.product_id
),
all_channel_product AS (
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
    o.organic_orders,
    o.organic_revenue,
    a.total_orders,
    a.total_revenue,
    ROUND(o.organic_revenue * 100.0 / a.total_revenue, 1)  AS organic_pct_of_product_rev
FROM organic_product        o
JOIN all_channel_product    a ON o.product_id = a.product_id
JOIN products_cleaned               p ON o.product_id = p.product_id
ORDER BY o.organic_revenue DESC
LIMIT 15;


-- ============================================================
-- QUERY 7 · Buyer Profile — Organic Search Purchasers
-- Who buys through organic search? Loyalty tier × income level
-- ============================================================

SELECT
    u.loyalty_tier,
    u.income_level,
    COUNT(DISTINCT pu.user_id)              AS buyers,
    ROUND(AVG(u.age), 1)                   AS avg_age,
    ROUND(SUM(pu.total_amount), 2)         AS total_revenue,
    ROUND(AVG(pu.total_amount), 2)         AS avg_spend_per_txn
FROM sessions_cleaned    s
JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
JOIN users_cleaned       u ON pu.user_id   = u.user_id
WHERE s.referrer_source = 'organic_search'
GROUP BY u.loyalty_tier, u.income_level
ORDER BY total_revenue DESC
LIMIT 10;

-- Key findings:
-- Bronze + high income    → 96 buyers, $11,565 revenue ($99.70 avg spend)
-- Bronze + medium income  → 148 buyers, $10,715 revenue ($57.00 avg spend)
-- Bronze + very_high      → 38 buyers, $8,654 revenue ($180.30 avg spend)
-- → Organic search is predominantly a new-customer (Bronze) acquisition channel


-- ============================================================
-- QUERY 8 · Monthly Organic Search Revenue Trend
-- Growth trajectory of organic channel over 3.5 years
-- ============================================================

SELECT
    DATE_FORMAT(pu.order_date, '%Y-%m')             AS yr_month,    -- MySQL
    -- TO_CHAR(pu.order_date, 'YYYY-MM')            AS yr_month,    -- PostgreSQL / DuckDB
    COUNT(DISTINCT pu.order_id)                     AS orders,
    ROUND(SUM(pu.total_amount), 2)                  AS revenue
FROM sessions_cleaned    s
JOIN purchases_cleaned  pu ON s.session_id = pu.session_id
WHERE s.referrer_source = 'organic_search'
GROUP BY yr_month
ORDER BY yr_month;

-- Trend: organic revenue grew ~11x from Jan 2023 ($186) to May 2026 ($2,120)
-- Consistent growth pattern — organic search compound value builds over time


-- ============================================================
-- QUERY 9 · Organic Search vs Display Ad — Head-to-Head
-- Volume channel vs efficiency channel comparison
-- ============================================================

SELECT
    s.referrer_source,
    COUNT(DISTINCT s.session_id)                                    AS total_sessions,
    COUNT(DISTINCT pu.order_id)                                     AS orders,
    ROUND(SUM(pu.total_amount), 2)                                  AS total_revenue,
    ROUND(AVG(pu.total_amount), 2)                                  AS avg_order_value,
    ROUND(SUM(pu.total_amount) / COUNT(DISTINCT s.session_id), 2)  AS revenue_per_session
FROM sessions_cleaned    s
LEFT JOIN purchases pu ON s.session_id = pu.session_id
WHERE s.referrer_source IN ('organic_search', 'display_ad')
GROUP BY s.referrer_source
ORDER BY total_revenue DESC;

-- organic_search: 6,950 sessions → $45,729 revenue → $6.58 per session
-- display_ad:       385 sessions → $3,557 revenue → $9.24 per session
-- → Display ad earns 40% more per session; organic wins on volume


-- ============================================================
-- SUMMARY OF FINDINGS
-- ============================================================
--
--  · Organic search is the #1 revenue channel: $45,729 (35.3% of total)
--    driven by volume — 6,950 sessions (36% of all traffic)
--
--  · Electronics leads organic revenue at $13,010 (28.5%) but
--    UNDER-INDEXES vs its overall share (31.1%) — it performs
--    relatively better through paid/direct channels
--
--  · Home & Kitchen OVER-INDEXES organically: 16.9% of organic
--    revenue vs 13.7% overall (+3.2 efficiency delta) — people
--    search for kitchen products with strong purchase intent
--
--  · Clothing & Accessories has the MOST orders (105) via organic
--    search but lower revenue per order ($55.50) — high-frequency,
--    lower-ticket buying behaviour
--
--  · Laptops ($4,838) and Fitness Equipment ($3,571) are the
--    top two subcategories driving organic Electronics and Sports
--
--  · Buyer profile: predominantly Bronze loyalty tier across all
--    income levels — organic search is a customer acquisition engine,
--    not a retention channel
--
--  · Revenue grew ~11x from Jan 2023 ($186) to May 2026 ($2,120)
--    showing compounding organic search value over time
--
-- ============================================================
-- END OF FILE
-- ============================================================
