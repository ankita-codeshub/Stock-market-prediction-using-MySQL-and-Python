USE market_prediction;

-- 1. Clear previous test data cleanly
TRUNCATE TABLE index_prices;
TRUNCATE TABLE alerts;
TRUNCATE TABLE predictions;

-- 2. Insert sample data for indices (if not already present)
INSERT IGNORE INTO sectors (name) VALUES ('Technology'), ('Financials');
INSERT IGNORE INTO indices (symbol, name, sector_id) VALUES
  ('RELIANCE.BSE', 'Reliance Industries', 1),
  ('INFY.BSE', 'Infosys', 1),
  ('TCS.BSE', 'TCS', 1),
  ('SBIN.BSE', 'State Bank of India', 2);

-- 3. Insert sample historical prices for testing triggers and procs
INSERT INTO index_prices (index_id, trading_date, close_price, volume) VALUES
  ((SELECT index_id FROM indices WHERE symbol='RELIANCE.BSE'), '2025-09-14', 200, 1000),
  ((SELECT index_id FROM indices WHERE symbol='RELIANCE.BSE'), '2025-09-15', 190, 5000),
  ((SELECT index_id FROM indices WHERE symbol='TCS.BSE'), '2025-09-14', 3400, 10000),
  ((SELECT index_id FROM indices WHERE symbol='TCS.BSE'), '2025-09-15', 3500, 15000);

-- 4. Manually run forecasting procedures to generate predictions and alerts
CALL predict_trend_v2((SELECT index_id FROM indices WHERE symbol='RELIANCE.BSE'), '2025-09-15');
CALL predict_trend_7days((SELECT index_id FROM indices WHERE symbol='TCS.BSE'), '2025-09-14');

-- 5. Check predictions generated for indexes
SELECT * FROM predictions ORDER BY created_at DESC;

-- 6. Check alerts generated especially forecast signals and volume spikes
SELECT * FROM alerts ORDER BY trading_date DESC LIMIT 10;

-- 7. Verify triggers ran properly by inserting recent price and checking alerts
INSERT INTO index_prices (index_id, trading_date, close_price, volume)
VALUES ((SELECT index_id FROM indices WHERE symbol='RELIANCE.BSE'), '2025-09-16', 180, 30000);

SELECT * FROM alerts ORDER BY created_at DESC LIMIT 10;

-- 8. Confirm essential table structure exists for index_prices, alerts, predictions etc.
SHOW TABLES;
DESCRIBE index_prices;
DESCRIBE alerts;
DESCRIBE predictions;

-- 9. Verify data for key indices (sample query for specific symbols)
SELECT i.symbol, COUNT(ip.price_id) AS price_count
FROM indices i
LEFT JOIN index_prices ip ON ip.index_id = i.index_id
WHERE i.symbol IN ('TCS.BSE', 'SBIN.BSE')
GROUP BY i.symbol;


-- 10. Optional: Insert a test alert directly for alert type coverage test
INSERT INTO alerts (index_id, trading_date, alert_type, message, severity)
VALUES ((SELECT index_id FROM indices WHERE symbol='TCS.BSE'), CURDATE(), 'FORECAST_SIGNAL', 'Test alert for automation verification', 2);

-- 11. List all alert types to check coverage
SELECT DISTINCT alert_type FROM alerts;
