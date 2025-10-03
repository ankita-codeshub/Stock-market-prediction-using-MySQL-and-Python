import json
import requests
import mysql.connector
from datetime import datetime
import matplotlib.pyplot as plt
import pandas as pd

# === 1. LOAD CONFIG FROM JSON ===
with open("config.json", "r") as f:
    config = json.load(f)

API_KEY = config["API_KEY"]
DB_CONFIG = config["DB_CONFIG"]

# === 2. CONNECT TO DATABASE ===
conn = mysql.connector.connect(**DB_CONFIG)
cursor = conn.cursor()

# === 3. FETCH SYMBOLS FROM `indices` TABLE ===
cursor.execute("SELECT index_id, symbol FROM indices;")
indices = cursor.fetchall()

if not indices:
    print("⚠️ No symbols found in `indices` table.")
    exit()

# === 4. FUNCTION TO FETCH DATA FROM ALPHA VANTAGE ===
def fetch_stock_data(symbol):
    url = f"https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol={symbol}&apikey={API_KEY}&outputsize=compact"
    response = requests.get(url)
    data = response.json()

    if "Time Series (Daily)" not in data:
        print(f"❌ Error fetching data for {symbol}: {data.get('Note', data)}")
        return []

    stock_data = []
    for date, values in data["Time Series (Daily)"].items():
        stock_data.append((
            symbol,
            date,
            float(values["4. close"]),
            int(float(values["5. volume"]))
        ))
    return stock_data

# === 5. FETCH, INSERT DATA, RUN FORECASTS ===
today_str = datetime.today().strftime('%Y-%m-%d')

for index_id, symbol in indices:
    print(f"\n📥 Fetching data for {symbol}...")
    stock_data = fetch_stock_data(symbol)
    if not stock_data:
        continue

    # Insert into staging
    cursor.executemany("""
        INSERT INTO staging_index_prices (symbol, trading_date, close_price, volume)
        VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE close_price=VALUES(close_price), volume=VALUES(volume);
    """, stock_data)
    conn.commit()

    # Move to main table
    cursor.execute("""
        INSERT INTO index_prices (index_id, trading_date, close_price, volume)
        SELECT i.index_id, s.trading_date, s.close_price, s.volume
        FROM staging_index_prices s
        JOIN indices i ON s.symbol = i.symbol
        ON DUPLICATE KEY UPDATE close_price = VALUES(close_price), volume = VALUES(volume);
    """)
    conn.commit()

    # Run 7-day forecast
    try:
        cursor.callproc("predict_trend_7days", (index_id, today_str))
        conn.commit()
        print(f"🔮 7-day forecast generated for {symbol}")
    except Exception as e:
        print(f"❌ Forecast procedure failed for {symbol}: {e}")

# Clear staging
cursor.execute("TRUNCATE TABLE staging_index_prices;")
conn.commit()
print("\n🧹 Staging table cleared")

# === 6. FETCH ALERTS ===
cursor.execute(f"""
    SELECT i.symbol, a.trading_date, a.alert_type, a.message, a.severity
    FROM alerts a
    JOIN indices i ON a.index_id = i.index_id
    WHERE a.trading_date BETWEEN '{today_str}' AND DATE_ADD('{today_str}', INTERVAL 7 DAY)
    ORDER BY a.trading_date, i.symbol;
""")
alerts = cursor.fetchall()

print("\n📊 ALERTS SUMMARY (Today + 7-Day Forecast):")
if alerts:
    for symbol, trading_date, alert_type, message, severity in alerts:
        print(f"{trading_date} | {symbol} | {alert_type} | {message} | Severity: {severity}")
else:
    print("No alerts generated.")

# === 7. DISPLAY 7-DAY FORECAST FOR ALL SYMBOLS ===
print("\n📈 UPCOMING 7-DAY MARKET FORECAST:")

for index_id, symbol in indices:
    cursor.execute(f"""
        SELECT trading_date, predicted_up, probability_up
        FROM predictions
        WHERE index_id = {index_id} 
          AND trading_date > '{today_str}' 
          AND model_version='v7'
        ORDER BY trading_date ASC;
    """)
    forecasts = cursor.fetchall()

    if not forecasts:
        print(f"{symbol}: ⚠️ No forecast data available!")
        continue

    print(f"\n🔹 Forecast for {symbol}:")
    warning_flag = False

    for trading_date, predicted_up, probability_up in forecasts:
        # Handle missing probability_up
        confidence = probability_up if probability_up is not None else 0.5
        status = "HIGH 📈" if predicted_up == 1 else "LOW 📉"
        print(f"  {trading_date}: {status} (Confidence: {confidence:.2%})")

        if predicted_up == 0:
            warning_flag = True

    # Print warning or confirmation
    if warning_flag:
        print(f"⚠️ WARNING: {symbol} is expected to go down on one or more days in the next 7 days!")
    else:
        print(f"✅ {symbol} is predicted to stay strong over the next 7 days.")

#======8.for showing the graph

# List of the four BSE symbols you care about
import matplotlib.pyplot as plt
import pandas as pd

bse_symbols = ["TCS.BSE", "SBIN.BSE", "INFY.BSE", "RELIANCE.BSE"]

fig, axes = plt.subplots(2, 2, figsize=(15, 10))  # 2x2 grid of plots
axes = axes.flatten()  # flatten to 1D list for easier iteration

print("\n📊 VISUALIZING 7-DAY RISK/TREND FORECASTS:")

for ax, symbol in zip(axes, bse_symbols):
    # Replace this with your real DB query using cursor
    query = f"""
        SELECT p.trading_date, p.probability_up, p.predicted_up
        FROM predictions p
        JOIN indices i ON p.index_id = i.index_id
        WHERE i.symbol = '{symbol}'
          AND p.model_version = 'v7'
          AND p.trading_date > '{today_str}'
        ORDER BY p.trading_date ASC;
    """
    cursor.execute(query)
    rows = cursor.fetchall()

    if not rows:
        print(f"{symbol}: No forecast data available for plotting.")
        continue

    df = pd.DataFrame(rows, columns=["trading_date", "probability_up", "predicted_up"])

    dates = df["trading_date"]
    prob = df["probability_up"]
    trend = df["predicted_up"]

    # Plot solid green line for upward trend segments
    ax.plot(dates[trend==1], prob[trend==1], color='green', linewidth=2, label='Upward Trend')

    # Plot solid red line for downward trend segments
    ax.plot(dates[trend==0], prob[trend==0], color='red', linewidth=2, label='Downward Trend')

    ax.set_title(f"{symbol} Risk/Trend - Next 7 Days")
    ax.set_xlabel("Date")
    ax.set_ylabel("Probability Up")
    ax.set_ylim(0, 1)
    ax.grid(True)
    ax.legend()
    ax.tick_params(axis='x', rotation=45)

plt.subplots_adjust(wspace=0.4, hspace=0.6)  # widen horizontal and vertical spacing
plt.show()




# === 9. VERIFY 7-DAY FORECASTS PER INDEX ===
print("\n✅ VERIFY 7-DAY FORECASTS PER INDEX:")
for index_id, symbol in indices:
    cursor.execute(f"""
        SELECT COUNT(*) FROM predictions
        WHERE index_id = {index_id} AND trading_date > '{today_str}' AND model_version='v7';
    """)
    count = cursor.fetchone()[0]
    if count == 7:
        print(f"{symbol}: ✅ 7-day forecast present")
    else:
        print(f"{symbol}: ⚠️ Only {count} forecast(s) present — check data!")

# === 10. CLOSE CONNECTION ===
cursor.close()
conn.close()
print("\n🎉 Process completed successfully!")
