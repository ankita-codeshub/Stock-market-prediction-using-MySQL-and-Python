-- ======================================================
-- Market Prediction Database Schema
-- Defines core tables and indexes only.
-- ======================================================

CREATE DATABASE IF NOT EXISTS market_prediction;
USE market_prediction;

DROP TABLE IF EXISTS predictions, model_coefficients, alerts, index_prices, `indices`, sectors, feature_table, staging_index_prices;

CREATE TABLE sectors (
    sector_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE `indices` (
    index_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(16) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    sector_id INT,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id)
);

CREATE TABLE index_prices (
    price_id INT AUTO_INCREMENT PRIMARY KEY,
    index_id INT NOT NULL,
    trading_date DATE NOT NULL,
    close_price DECIMAL(18,4) NOT NULL,
    volume BIGINT NOT NULL DEFAULT 0,
    UNIQUE(index_id, trading_date),
    FOREIGN KEY (index_id) REFERENCES `indices`(index_id)
);

CREATE TABLE alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    index_id INT,
    trading_date DATE NOT NULL,
    alert_type VARCHAR(64) NOT NULL,
    message VARCHAR(400),
    severity INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (index_id) REFERENCES `indices`(index_id)
);

CREATE TABLE model_coefficients (
    model_version VARCHAR(20) NOT NULL,
    feature_name VARCHAR(50) NOT NULL,
    coefficient DECIMAL(15,8) NOT NULL,
    PRIMARY KEY (model_version, feature_name)
);

CREATE TABLE predictions (
    prediction_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    index_id INT NOT NULL,
    trading_date DATE NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    probability_up DECIMAL(6,4),
    predicted_up TINYINT(1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (index_id) REFERENCES `indices`(index_id)
);

CREATE TABLE feature_table (
    index_id INT NOT NULL,
    trading_date DATE NOT NULL,
    daily_return DECIMAL(10,2),
    ma7_return_pct DECIMAL(10,2),
    vol30_pct DECIMAL(10,2),
    PRIMARY KEY(index_id, trading_date)
);

CREATE TABLE staging_index_prices (
    symbol VARCHAR(16),
    trading_date DATE,
    close_price DECIMAL(18,4),
    volume BIGINT,
    PRIMARY KEY(symbol, trading_date)
);

CREATE INDEX idx_prices_index_date ON index_prices(index_id, trading_date);
CREATE INDEX idx_alerts_index_date ON alerts(index_id, trading_date);
CREATE INDEX idx_features_index_date ON feature_table(index_id, trading_date);
