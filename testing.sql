-- ======================================================
-- Market Prediction Dev / Testing Logic
-- For developer setup, manual verification, and code demonstration
-- ======================================================

USE market_prediction;

-- Truncate tables for clean state during repeated tests
TRUNCATE TABLE index_prices;
TRUNCATE TABLE alerts;

-- Insert sample prices for quick trigger/procedure testing

INSERT INTO index_prices (index_id, trading_date, close_price, volume) VALUES
    (1, '2025-09-14', 100, 1000),
	(2, '2025-09-16', 96, 15000),
    (3, '2025-09-14', 110, 5000),  -- New index_id 3
    (4, '2025-09-15', 220, 7000)   -- New index_id 4

ON DUPLICATE KEY UPDATE
    close_price = VALUES(close_price),
    volume = VALUES(volume);
SELECT * FROM index_prices ORDER BY index_id, trading_date;


-- Basic selects for quick validation (edit as needed)
SELECT * FROM index_prices WHERE index_id = 1 ORDER BY trading_date;
SELECT * FROM alerts ORDER BY alert_id DESC LIMIT 5;

-- Show triggers
SHOW TRIGGERS LIKE 'index_prices';

-- Run prediction procedures for manual verification
CALL predict_trend_v2(1, '2025-09-15');
CALL predict_trend_v2(1, '2025-09-16');
CALL predict_trend_v2(2, '2025-09-15');
CALL score_logistic_model('v1', 1, '2025-09-16', 0.5, 0.7, 0.3);
CALL predict_trend_7days(1, '2025-09-15');

-- Quick check on output
SELECT * FROM predictions ORDER BY created_at DESC;
SELECT * FROM alerts WHERE alert_type = 'FORECAST_SIGNAL' ORDER BY trading_date DESC;

-- Basic table inspection
SHOW TABLES;
DESCRIBE index_prices;
DESCRIBE indices;
DESCRIBE predictions;

-- Data checks
SELECT * FROM indices;
SELECT * FROM index_prices WHERE trading_date > '2025-09-01' ORDER BY index_id, trading_date;
SELECT index_id, symbol, name FROM indices WHERE symbol IN ('TCS.BSE', 'SBIN.BSE');

-- Data checks for TCS.BSE and SBIN.BSE
SELECT symbol, COUNT(*) FROM staging_index_prices WHERE symbol IN ('TCS.BSE', 'SBIN.BSE') GROUP BY symbol;
SELECT i.symbol, COUNT(*)
FROM index_prices ip
JOIN indices i ON ip.index_id = i.index_id
WHERE i.symbol IN ('TCS.BSE', 'SBIN.BSE')
GROUP BY i.symbol;
CALL predict_trend_7days((SELECT index_id FROM indices WHERE symbol = 'TCS.BSE'), CURDATE());
CALL predict_trend_7days((SELECT index_id FROM indices WHERE symbol = 'SBIN.BSE'), CURDATE());
SELECT * FROM predictions WHERE index_id IN 
  ((SELECT index_id FROM indices WHERE symbol IN ('TCS.BSE', 'SBIN.BSE')))
ORDER BY trading_date DESC LIMIT 10;


SELECT index_id, symbol FROM indices WHERE symbol LIKE '%.BSE';

SELECT index_id, COUNT(*) AS num_records
FROM index_prices
GROUP BY index_id;


SELECT * FROM predictions WHERE index_id = index_id ORDER BY created_at DESC;

SELECT * FROM alerts WHERE alert_type='FORECAST_SIGNAL' ORDER BY trading_date DESC;
SELECT alert_type, COUNT(*) FROM alerts GROUP BY alert_type;
SELECT * FROM alerts WHERE trading_date > DATE_SUB(CURDATE(), INTERVAL 30 DAY);
SELECT DISTINCT alert_type FROM alerts;
SELECT * FROM alerts ORDER BY trading_date DESC LIMIT 10;
INSERT INTO alerts (index_id, trading_date, alert_type, message, severity)
VALUES (1, CURDATE(), 'FORECAST_SIGNAL', 'Test forecast alert', 2);






