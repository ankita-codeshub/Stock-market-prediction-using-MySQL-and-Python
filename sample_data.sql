-- ======================================================
-- Market Prediction Sample Data Script
-- Inserts sample data and minimal initial testing
-- ======================================================

USE market_prediction;

INSERT INTO sectors (name) VALUES 
    ('Technology'), ('Financials'), ('Healthcare')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO `indices` (symbol, name, sector_id) VALUES
    ('RELIANCE.BSE', 'Reliance Industries', 1),
    ('INFY.BSE', 'Infosys', 1),
    ('TCS.BSE', 'TCS', 1),
    ('SBIN.BSE', 'State Bank of India', 1)
ON DUPLICATE KEY UPDATE name = VALUES(name), sector_id = VALUES(sector_id);

INSERT INTO model_coefficients (model_version, feature_name, coefficient) VALUES
    ('v1', 'intercept', -0.02),
    ('v1', 'daily_return', 0.8),
    ('v1', 'ma7_return_pct', 0.5),
    ('v1', 'vol30_pct', -1.2)
ON DUPLICATE KEY UPDATE coefficient = VALUES(coefficient);

INSERT INTO index_prices (index_id, trading_date, close_price, volume)
VALUES (1, '2025-09-15', 100, 10000)
ON DUPLICATE KEY UPDATE close_price = VALUES(close_price), volume = VALUES(volume);

-- Minimal verification queries (for dev/test setup):
-- SELECT * FROM indices;
-- SELECT * FROM index_prices;
-- SELECT * FROM model_coefficients;
