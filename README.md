📈 Stock Market Prediction
A Python-based stock market prediction system that integrates Alpha Vantage API with a MySQL backend. It automates stock data ingestion, generates 7-day predictive insights, and provides risk alerts with trend visualizations. The system currently tracks 4 BSE stocks (TCS, SBIN, INFY, RELIANCE) but can be easily extended to more.

## Table of Contents

1. [🛠️ Technologies Used](#technologies-used)
2. [📂 Project Structure](#project-structure)
3. [⚙️ Installation](#installation)
4. [▶️ Usage](#usage)
5. [📊 Example](#example-output)
6. [➕ Adding More Stocks](#adding-more-stocks)
7. [🌐 API Option](#api-option)
8. [📦 Requirements](#requirements)
9. [📜 License](#license)

## 🛠️ Technologies Used

- Python 3.9+
- MySQL
- Alpha Vantage API
- Pandas & NumPy
- Matplotlib
- FastAPI (optional)
- Streamlit (optional)

## 📂 Project Structure
```
├── config.json # API key + MySQL credentials (ignored in .gitignore)
├── schema.sql # Database schema for predictions & alerts
├── fetch_data.py # Main script for fetching & forecasting
├── app.py # (Optional) FastAPI app for serving forecasts
├── requirements.txt # Python dependencies
└── README.md # Project documentation
```

---

## ⚙️ Installation

1. **Clone Repository**  

git clone https://github.com/<username>/stock-market-prediction.git
cd stock-market-prediction

2️⃣ Install Dependencies (Main Step)

🚀 Important: This is the main step. Make sure it runs successfully.
```pip install -r requirements.txt```


3. Setup Database
mysql -u root -p < schema.sql

4. Configure API Key & Database

Update config.json (not pushed to GitHub):

{
  "API_KEY": "YOUR_ALPHA_VANTAGE_KEY",
  "DB_CONFIG": {
    "host": "localhost",
    "user": "root",
    "password": "yourpassword",
    "database": "market_prediction"
  }
}

5. Insert Initial Stocks
INSERT INTO sectors (name) VALUES ('IT'), ('Banking'), ('Energy');

INSERT INTO indices (symbol, name, sector_id)
VALUES
('TCS.BSE', 'Tata Consultancy Services', 1),
('INFY.BSE', 'Infosys', 1),
('SBIN.BSE', 'State Bank of India', 2),
('RELIANCE.BSE', 'Reliance Industries', 3);

▶️ Usage:
Run the main script:
python fetch_data.py

This will:
Fetch latest stock prices from Alpha Vantage
Store them in MySQL
Generate 7-day predictions
Display alerts and visualization graphs

📊 Example Output:
📥 Fetching data for TCS.BSE...
🔮 7-day forecast generated
✅ TCS.BSE is predicted to stay strong over the next 7 days.
⚠️ SBIN.BSE is expected to go down on one or more days in the next 7 days!


Visualization includes probability graphs:

🟢 Green line → Upward trend
🔴 Red line → Downward trend
➕ Adding More Stocks

Insert into indices table:

INSERT INTO indices (symbol, name, sector_id)
VALUES ('HDFCBANK.BSE', 'HDFC Bank', 2);


Re-run fetch_data.py → new stock included automatically.

🌐 API Option

To serve forecasts via API:
Install FastAPI + Uvicorn:
pip install fastapi uvicorn


Run API:
uvicorn app:app --reload


Access:
http://127.0.0.1:8000/forecast/TCS.BSE

📦 Requirements:
All dependencies are listed in requirements.txt:

requests
mysql-connector-python
pandas
numpy
matplotlib
fastapi
uvicorn
streamlit
plotly


Install with:
pip install -r requirements.txt

📜 License:
This project is licensed under the MIT License © 2025.
You are free to use, modify, and distribute this project with attribution.
