-- ======================================================
-- Market Prediction Database Procedures and Triggers
-- Triggers and all stored procedures only.
-- ======================================================

USE market_prediction;

DELIMITER $$

-- Drop trigger if exists before creating new one
DROP TRIGGER IF EXISTS trg_after_price_insert$$

CREATE TRIGGER trg_after_price_insert
AFTER INSERT ON index_prices
FOR EACH ROW
BEGIN
    DECLARE prev_close, close_3_ago, cum_drop DECIMAL(18,4);
    DECLARE pct_change, vol_ratio DOUBLE;
    DECLARE avg_vol DOUBLE;
    DECLARE last_vol BIGINT;
    DECLARE next_date DATE;
    DECLARE i INT DEFAULT 0;

    -- Get previous day's close
    SELECT close_price INTO prev_close
    FROM index_prices
    WHERE index_id = NEW.index_id AND trading_date < NEW.trading_date
    ORDER BY trading_date DESC LIMIT 1;

    IF prev_close IS NOT NULL THEN
        SET pct_change = 100 * (NEW.close_price - prev_close) / prev_close;
        IF pct_change <= -5 THEN
            INSERT INTO alerts(index_id, trading_date, alert_type, message, severity)
            VALUES(NEW.index_id, NEW.trading_date, 'SINGLE_DAY_DROP', CONCAT('Single day drop: ', ROUND(pct_change,2), '%'),2);
        END IF;
    END IF;

    -- 3-day cumulative drop check
    SELECT MIN(close_price) INTO close_3_ago
    FROM (SELECT close_price FROM index_prices
          WHERE index_id = NEW.index_id AND trading_date <= NEW.trading_date
          ORDER BY trading_date DESC LIMIT 3) AS t;

    IF close_3_ago IS NOT NULL THEN
        SET cum_drop = 100 * (NEW.close_price - close_3_ago) / close_3_ago;
        IF cum_drop <= -10 THEN
            INSERT INTO alerts(index_id, trading_date, alert_type, message, severity)
            VALUES(NEW.index_id, NEW.trading_date, '3_DAY_CUMULATIVE_DROP', CONCAT('3-day cumulative drop: ', ROUND(cum_drop,2), '%'),3);
        END IF;
    END IF;

    -- Volume spike check
    SELECT AVG(volume) INTO avg_vol
    FROM (SELECT volume FROM index_prices WHERE index_id = NEW.index_id ORDER BY trading_date DESC LIMIT 10) AS v;

    IF avg_vol > 0 THEN
        SET vol_ratio = NEW.volume / avg_vol;
        IF vol_ratio >= 3 THEN
            INSERT INTO alerts(index_id, trading_date, alert_type, message, severity)
            VALUES(NEW.index_id, NEW.trading_date, 'VOLUME_SPIKE', CONCAT('Volume spike ratio ', ROUND(vol_ratio,2)),2);
        END IF;
    END IF;

    -- Today price check alert
    IF prev_close IS NOT NULL THEN
        SET pct_change = 100 * (NEW.close_price - prev_close) / prev_close;
        INSERT INTO alerts(index_id, trading_date, alert_type, message, severity)
        VALUES(
            NEW.index_id,
            NEW.trading_date,
            'TODAY_PRICE_CHECK',
            CONCAT('Today close: ', NEW.close_price, ' | Change vs yesterday: ', ROUND(pct_change,2),'%'),
            CASE WHEN pct_change > 0 THEN 1 ELSE 2 END
        );
    END IF;

    -- Run predict_trend_v2 for next 7 days and insert alert if predicted_up=1
    SET i = 0;
    WHILE i < 7 DO
        SET next_date = DATE_ADD(NEW.trading_date, INTERVAL i+1 DAY);
        CALL predict_trend_v2(NEW.index_id, next_date);

        IF EXISTS (
            SELECT 1 FROM predictions
            WHERE index_id = NEW.index_id AND trading_date = next_date AND predicted_up = 1
        ) THEN
            INSERT INTO alerts(index_id, trading_date, alert_type, message, severity)
            VALUES(
                NEW.index_id,
                next_date,
                'PREDICTION_UP',
                CONCAT('Predicted HIGH for ', DATE_FORMAT(next_date,'%Y-%m-%d')),
                1
            );
        END IF;

        SET i = i + 1;
    END WHILE;
END$$

-- Drop and create predict_trend_v2
DROP PROCEDURE IF EXISTS predict_trend_v2$$

CREATE PROCEDURE predict_trend_v2(IN p_index_id INT, IN p_as_of DATE)
BEGIN
    DECLARE ma7, vol30, last_return DOUBLE;
    DECLARE vol20_avg, vol20_stddev DOUBLE;
    DECLARE last_vol BIGINT;
    DECLARE vol_zscore DOUBLE;
    DECLARE market_dir VARCHAR(10);

    DROP TEMPORARY TABLE IF EXISTS tmp_ret;

    CREATE TEMPORARY TABLE tmp_ret AS
    SELECT trading_date,
           100 * (close_price - LAG(close_price) OVER (PARTITION BY index_id ORDER BY trading_date))
           / NULLIF(LAG(close_price) OVER (PARTITION BY index_id ORDER BY trading_date),0) AS daily_ret,
           volume
    FROM index_prices
    WHERE index_id = p_index_id AND trading_date <= p_as_of;

    SELECT AVG(daily_ret) INTO ma7 FROM (SELECT daily_ret FROM tmp_ret ORDER BY trading_date DESC LIMIT 7) AS t;
    SELECT STDDEV_POP(daily_ret) INTO vol30 FROM (SELECT daily_ret FROM tmp_ret ORDER BY trading_date DESC LIMIT 30) AS t;
    SELECT daily_ret INTO last_return FROM (SELECT daily_ret FROM tmp_ret ORDER BY trading_date DESC LIMIT 1) AS t;
    SELECT volume INTO last_vol FROM (SELECT volume FROM tmp_ret ORDER BY trading_date DESC LIMIT 1) AS t;

    SELECT AVG(volume), STDDEV_POP(volume) INTO vol20_avg, vol20_stddev
    FROM (SELECT volume FROM tmp_ret ORDER BY trading_date DESC LIMIT 20) AS t;

    IF vol20_stddev IS NULL OR vol20_stddev = 0 OR last_vol IS NULL THEN
        SET vol_zscore = NULL;
    ELSE
        SET vol_zscore = (last_vol - vol20_avg) / vol20_stddev;
    END IF;

    IF ma7 IS NULL THEN
        SET market_dir = 'NO_DATA';
    ELSEIF ma7 >= 0.5 AND (vol30 IS NULL OR vol30 <= 2) AND (vol_zscore IS NULL OR vol_zscore <= 2) THEN
        SET market_dir = 'UP';
    ELSEIF ma7 < -0.5 OR (vol30 IS NOT NULL AND vol30 >= 4) OR (vol_zscore IS NOT NULL AND vol_zscore >= 3) THEN
        SET market_dir = 'DOWN';
    ELSE
        SET market_dir = 'NEUTRAL';
    END IF;

    INSERT INTO predictions(index_id, trading_date, model_version, probability_up, predicted_up)
    VALUES(
        p_index_id,
        p_as_of,
        'v2',
        CASE WHEN market_dir='UP' THEN 1 ELSE 0 END,
        CASE WHEN market_dir='UP' THEN 1 ELSE 0 END
    );

    DROP TEMPORARY TABLE IF EXISTS tmp_ret;
END$$

-- Drop and create predict_trend_7days
DROP PROCEDURE IF EXISTS predict_trend_7days$$

CREATE PROCEDURE predict_trend_7days(IN p_index_id INT, IN p_start_date DATE)
BEGIN
    DECLARE forecast_date DATE;
    DECLARE counter INT DEFAULT 1;
    DECLARE avg_return DECIMAL(10,4);
    DECLARE vol_avg DECIMAL(18,4);
    DECLARE trend_direction VARCHAR(10);

    SET forecast_date = DATE_ADD(p_start_date, INTERVAL 1 DAY);

    forecast_loop: WHILE counter <= 7 DO
        SELECT AVG(100 * (a.close_price - b.close_price) / NULLIF(b.close_price,0))
        INTO avg_return
        FROM index_prices a
        JOIN index_prices b 
          ON a.index_id = b.index_id 
         AND b.trading_date = (
              SELECT MAX(c.trading_date)
              FROM index_prices c
              WHERE c.index_id = a.index_id
                AND c.trading_date < a.trading_date
          )
        WHERE a.index_id = p_index_id
          AND a.trading_date <= forecast_date
          AND a.trading_date > DATE_SUB(forecast_date, INTERVAL 30 DAY);

        SELECT AVG(volume)
        INTO vol_avg
        FROM index_prices
        WHERE index_id = p_index_id
          AND trading_date <= forecast_date
          AND trading_date > DATE_SUB(forecast_date, INTERVAL 20 DAY);

        IF avg_return IS NULL THEN
            SET trend_direction = 'NO_DATA';
        ELSEIF avg_return >= 0.5 AND vol_avg IS NOT NULL AND vol_avg > 0 THEN
            SET trend_direction = 'UP';
        ELSEIF avg_return <= -0.5 THEN
            SET trend_direction = 'DOWN';
        ELSE
            SET trend_direction = 'NEUTRAL';
        END IF;

        INSERT INTO predictions (index_id, trading_date, model_version, probability_up, predicted_up)
        VALUES (
            p_index_id,
            forecast_date,
            'v7',
            CASE 
                WHEN trend_direction = 'UP' THEN 0.8
                WHEN trend_direction = 'NEUTRAL' THEN 0.5
                ELSE 0.2
            END,
            CASE WHEN trend_direction = 'UP' THEN 1 ELSE 0 END
        )
        ON DUPLICATE KEY UPDATE
            probability_up = VALUES(probability_up),
            predicted_up = VALUES(predicted_up),
            model_version = VALUES(model_version);

        IF trend_direction = 'UP' OR trend_direction = 'DOWN' THEN
            INSERT INTO alerts(index_id, trading_date, alert_type, message, severity)
            VALUES (
                p_index_id,
                forecast_date,
                'FORECAST_SIGNAL',
                CONCAT('Forecast for ', forecast_date, ': ', trend_direction),
                CASE WHEN trend_direction = 'UP' THEN 1 ELSE 3 END
            )
            ON DUPLICATE KEY UPDATE
                message = VALUES(message),
                severity = VALUES(severity);
        END IF;

        SET forecast_date = DATE_ADD(forecast_date, INTERVAL 1 DAY);
        SET counter = counter + 1;
    END WHILE forecast_loop;

    -- Optional: update NULL probability values if any
    UPDATE predictions
    SET probability_up = CASE WHEN predicted_up = 1 THEN 0.8 ELSE 0.2 END
    WHERE index_id = p_index_id
      AND trading_date > p_start_date
      AND probability_up IS NULL;
END$$

DELIMITER ;
