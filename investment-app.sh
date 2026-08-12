#!/bin/bash
set -euo pipefail

# Amazon Linux 2023 EC2 user-data for the Scale server-from-code demonstration.
# Student-editable, non-secret configuration.
TICKER="NVDA"
FINNHUB_SECRET_ID="investment-app/finnhub-key"
DB_PASSWORD_SECRET_ID="investment-app/db-password"

exec > >(tee /var/log/investment-app-install.log | logger -t user-data -s 2>/dev/console) 2>&1

dnf install -y python3 python3-pip nginx postgresql15 postgresql15-server

if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then
  postgresql-setup --initdb
fi

# The app connects over localhost with a password instead of becoming the
# operating-system postgres user.
sed -Ei 's/^(host[[:space:]]+all[[:space:]]+all[[:space:]]+127\.0\.0\.1\/32[[:space:]]+).*/\1scram-sha-256/' /var/lib/pgsql/data/pg_hba.conf
systemctl enable --now postgresql
systemctl restart postgresql

read_secret() {
  local secret_id="$1"
  local value

  for attempt in $(seq 1 12); do
    if value="$(aws secretsmanager get-secret-value \
      --secret-id "$secret_id" \
      --query SecretString \
      --output text)"; then
      printf '%s' "$value"
      return 0
    fi

    echo "Waiting for permission to read $secret_id (attempt $attempt/12)..." >&2
    sleep 5
  done

  echo "Could not read Secrets Manager secret: $secret_id" >&2
  return 1
}

FINNHUB_KEY="$(read_secret "$FINNHUB_SECRET_ID")"
DB_PASSWORD="$(read_secret "$DB_PASSWORD_SECRET_ID")"

export DB_PASSWORD
runuser -u postgres -- psql --set=ON_ERROR_STOP=1 <<'SQL'
\getenv db_password DB_PASSWORD
CREATE ROLE investment_app LOGIN PASSWORD :'db_password';
CREATE DATABASE investment_app OWNER investment_app;
SQL

useradd --system --home-dir /opt/investment-app --shell /sbin/nologin investment-app
mkdir -p /opt/investment-app
chown investment-app:investment-app /opt/investment-app

python3 -m venv /opt/investment-app/venv
/opt/investment-app/venv/bin/pip install --no-cache-dir \
  Flask==3.1.1 \
  gunicorn==23.0.0 \
  'psycopg[binary]==3.2.9' \
  requests==2.32.4

cat >/opt/investment-app/app.py <<'PYTHON'
import base64
import os

import psycopg
import requests
from flask import Flask, flash, redirect, render_template_string, request, url_for


app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET", "classroom-only-secret")

TICKER = os.environ.get("TICKER", "NVDA").upper()
FINNHUB_KEY = base64.b64decode(os.environ["FINNHUB_KEY_B64"]).decode()
DB_PASSWORD = base64.b64decode(os.environ["DB_PASSWORD_B64"]).decode()


def connect():
    return psycopg.connect(
        host="127.0.0.1",
        dbname="investment_app",
        user="investment_app",
        password=DB_PASSWORD,
    )


def initialize_database():
    with connect() as conn:
        conn.execute("SELECT pg_advisory_xact_lock(3122026)")
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS ledger_entries (
                id BIGSERIAL PRIMARY KEY,
                kind TEXT NOT NULL,
                cash_delta NUMERIC(14, 2) NOT NULL,
                shares_delta INTEGER NOT NULL,
                share_price NUMERIC(14, 4),
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS saved_prices (
                ticker TEXT PRIMARY KEY,
                price NUMERIC(14, 4) NOT NULL,
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        )
        count = conn.execute("SELECT COUNT(*) FROM ledger_entries").fetchone()[0]
        if count == 0:
            conn.execute(
                """
                INSERT INTO ledger_entries (kind, cash_delta, shares_delta)
                VALUES ('starting balance', 10000.00, 0)
                """
            )


def fetch_price(conn):
    try:
        response = requests.get(
            "https://finnhub.io/api/v1/quote",
            params={"symbol": TICKER, "token": FINNHUB_KEY},
            timeout=5,
        )
        response.raise_for_status()
        price = float(response.json().get("c", 0))
        if price <= 0:
            raise ValueError("Finnhub returned no current price")
        conn.execute(
            """
            INSERT INTO saved_prices (ticker, price)
            VALUES (%s, %s)
            ON CONFLICT (ticker) DO UPDATE
            SET price = EXCLUDED.price, updated_at = NOW()
            """,
            (TICKER, price),
        )
        return price
    except (requests.RequestException, ValueError):
        saved = conn.execute(
            "SELECT price FROM saved_prices WHERE ticker = %s", (TICKER,)
        ).fetchone()
        if saved:
            return float(saved[0])
        raise


def account_state(conn):
    rows = conn.execute(
        """
        SELECT kind, cash_delta, shares_delta, share_price
        FROM ledger_entries
        ORDER BY id
        """
    ).fetchall()

    cash = sum(float(row[1]) for row in rows)
    shares = sum(row[2] for row in rows)
    held_cost = 0.0
    held_shares = 0

    # Average-cost accounting keeps the example small while still calculating
    # profit/loss for only the shares that are currently held.
    for kind, _, share_delta, share_price in rows:
        if kind == "buy":
            held_cost += share_delta * float(share_price)
            held_shares += share_delta
        elif kind == "sell" and held_shares:
            average_cost = held_cost / held_shares
            held_cost -= abs(share_delta) * average_cost
            held_shares += share_delta

    return cash, shares, held_cost


PAGE = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ ticker }} paper trading</title>
  <style>
    body { margin: 0; background: #f4f6f8; color: #16202a; font: 18px/1.5 system-ui, sans-serif; }
    main { max-width: 760px; margin: 60px auto; padding: 0 20px; }
    .card { background: white; border-radius: 16px; padding: 32px; box-shadow: 0 8px 30px #0001; }
    h1 { margin-top: 0; }
    .price { font-size: 42px; font-weight: 750; }
    .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin: 28px 0; }
    .stat { background: #eef2f6; border-radius: 10px; padding: 16px; }
    .label { color: #5d6b78; font-size: 14px; text-transform: uppercase; }
    .value { font-size: 24px; font-weight: 700; }
    .up { color: #14833b; } .down { color: #c83232; }
    form { display: inline; }
    button { border: 0; border-radius: 9px; padding: 12px 28px; font: inherit; font-weight: 700; cursor: pointer; }
    .buy { background: #1769e0; color: white; } .sell { background: #dfe5eb; color: #16202a; }
    .message { background: #fff4c2; border-radius: 8px; margin-bottom: 16px; padding: 12px; }
    @media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
<main>
  {% for message in get_flashed_messages() %}<div class="message">{{ message }}</div>{% endfor %}
  <section class="card">
    <div class="label">Paper trading · pretend money</div>
    <h1>{{ ticker }}</h1>
    <div class="price">${{ '%.2f'|format(price) }}</div>
    <div class="grid">
      <div class="stat"><div class="label">Cash</div><div class="value">${{ '%.2f'|format(cash) }}</div></div>
      <div class="stat"><div class="label">Shares</div><div class="value">{{ shares }}</div></div>
      <div class="stat"><div class="label">Open gain/loss</div><div class="value {{ 'up' if gain >= 0 else 'down' }}">${{ '%.2f'|format(gain) }}</div></div>
    </div>
    <form method="post" action="{{ url_for('trade') }}">
      <button class="buy" name="side" value="buy">Buy one share</button>
      <button class="sell" name="side" value="sell">Sell one share</button>
    </form>
  </section>
</main>
</body>
</html>
"""


@app.get("/health")
def health():
    # Deliberately does not query PostgreSQL. This endpoint answers whether this
    # application process can respond, not whether a shared dependency is healthy.
    return {"status": "ok"}


@app.get("/")
def index():
    with connect() as conn:
        price = fetch_price(conn)
        cash, shares, held_cost = account_state(conn)
    gain = shares * price - held_cost
    return render_template_string(
        PAGE,
        ticker=TICKER,
        price=price,
        cash=cash,
        shares=shares,
        gain=gain,
    )


@app.post("/trade")
def trade():
    side = request.form.get("side")
    if side not in {"buy", "sell"}:
        return "invalid trade", 400

    with connect() as conn:
        conn.execute("SELECT pg_advisory_xact_lock(3122026)")
        price = fetch_price(conn)
        cash, shares, _ = account_state(conn)

        if side == "buy" and cash < price:
            flash("Not enough pretend cash to buy one share.")
        elif side == "sell" and shares < 1:
            flash("You do not own a share to sell.")
        else:
            share_delta = 1 if side == "buy" else -1
            cash_delta = -price if side == "buy" else price
            conn.execute(
                """
                INSERT INTO ledger_entries
                    (kind, cash_delta, shares_delta, share_price)
                VALUES (%s, %s, %s, %s)
                """,
                (side, cash_delta, share_delta, price),
            )

    return redirect(url_for("index"))


initialize_database()
PYTHON

chown -R investment-app:investment-app /opt/investment-app

# Base64 keeps arbitrary secret characters valid in a systemd EnvironmentFile.
cat >/etc/investment-app.env <<EOF
TICKER=$TICKER
FINNHUB_KEY_B64=$(printf '%s' "$FINNHUB_KEY" | base64 -w0)
DB_PASSWORD_B64=$(printf '%s' "$DB_PASSWORD" | base64 -w0)
EOF
chmod 600 /etc/investment-app.env
unset DB_PASSWORD

cat >/etc/systemd/system/investment-app.service <<'SYSTEMD'
[Unit]
Description=Investment paper-trading app
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
User=investment-app
Group=investment-app
WorkingDirectory=/opt/investment-app
EnvironmentFile=/etc/investment-app.env
ExecStart=/opt/investment-app/venv/bin/gunicorn --workers 1 --bind 127.0.0.1:8000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
SYSTEMD

cat >/etc/nginx/nginx.conf <<'NGINX'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;

    server {
        listen 80 default_server;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX

systemctl daemon-reload
systemctl enable --now investment-app nginx

curl --fail --retry 12 --retry-delay 5 http://127.0.0.1/health
echo "Investment app installation complete."