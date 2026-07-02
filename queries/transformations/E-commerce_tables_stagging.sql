-- ============================================================
-- E-COMMERCE DATASETS — SQL STAGGING
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
--  reviews_cleaned      (review_id, user_id, product_id, purchase_id,
--                       rating, title, review_text, review_date)



-- Creaing Database Design
CREATE DATABASE ecommerce_analytics;
USE ecommerce_analytics;


-- Users Table
CREATE TABLE users_cleaned (
    user_id VARCHAR(50) PRIMARY KEY,
    age INT,
    gender VARCHAR(20),
    country VARCHAR(10),
    city VARCHAR(100),
    signup_date DATE,
    income_level VARCHAR(20),
    preferred_category VARCHAR(100),
    loyalty_tier VARCHAR(20)
);

-- Products Table
CREATE TABLE products_cleaned (
    product_id VARCHAR(50) PRIMARY KEY,
    product_name VARCHAR(255),
    product_description TEXT,
    category VARCHAR(100),
    subcategory VARCHAR(100),
    brand VARCHAR(100),
    price DECIMAL(10,2),
    rating_avg DECIMAL(3,2),
    review_count INT,
    stock_quantity INT,
    date_added DATE
);

-- Sessions Table
CREATE TABLE sessions_cleaned (
    session_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50),
    start_time DATETIME,
    device_type VARCHAR(50),
    referrer_source VARCHAR(50),
    is_converted BOOLEAN,
    FOREIGN KEY (user_id)
    REFERENCES users_cleaned(user_id)
);

-- Interactions Table
CREATE TABLE interactions_cleaned (
    interaction_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50),
    product_id VARCHAR(50),
    session_id VARCHAR(50),
    interaction_type VARCHAR(50),
    interaction_time VARCHAR(20),
    dwell_time_ms BIGINT,
    FOREIGN KEY (user_id)
        REFERENCES users_cleaned(user_id),
    FOREIGN KEY (product_id)
        REFERENCES products_cleaned(product_id),
    FOREIGN KEY (session_id)
        REFERENCES sessions_cleaned(session_id)
);

-- Purchase Table
CREATE TABLE purchases_cleaned (
    purchase_id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50),
    user_id VARCHAR(50),
    product_id VARCHAR(50),
    session_id VARCHAR(50),
    interaction_id VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10,2),
    total_amount DECIMAL(12,2),
    order_date DATETIME,
    FOREIGN KEY (user_id)
        REFERENCES users_cleaned(user_id),
    FOREIGN KEY (product_id)
        REFERENCES products_cleaned(product_id),
    FOREIGN KEY (session_id)
        REFERENCES sessions_cleaned(session_id),
    FOREIGN KEY (interaction_id)
        REFERENCES interactions_cleaned(interaction_id)
);

-- Review Tables
CREATE TABLE reviews_cleaned (
    review_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50),
    product_id VARCHAR(50),
    purchase_id VARCHAR(50),
    rating INT,
    title VARCHAR(255),
    review_text TEXT,
    review_date DATETIME,
    FOREIGN KEY (user_id)
        REFERENCES users_cleaned(user_id),
    FOREIGN KEY (product_id)
        REFERENCES products_cleaned(product_id),
    FOREIGN KEY (purchase_id)
        REFERENCES purchases_cleaned(purchase_id)
);

-- Analytics Optimization Indexes
-- These will dramatically improve query performance.

CREATE INDEX idx_user_country
ON users_cleaned(country);
CREATE INDEX idx_product_category
ON products_cleaned(category);
CREATE INDEX idx_product_brand
ON products_cleaned(brand);
CREATE INDEX idx_session_source
ON sessions_cleaned(referrer_source);
CREATE INDEX idx_session_user
ON sessions_cleaned(user_id);
CREATE INDEX idx_purchase_date
ON purchases_cleaned(order_date);
CREATE INDEX idx_purchase_product
ON purchases_cleaned(product_id);
CREATE INDEX idx_purchase_user
ON purchases_cleaned(user_id);
CREATE INDEX idx_review_rating
ON reviews_cleaned(rating);

-- ============================================================
-- END OF FILE
-- ============================================================
