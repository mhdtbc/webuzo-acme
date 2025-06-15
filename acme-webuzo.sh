#!/bin/bash

#################### CONFIGURATION ########################

# Webuzo DNS API config (use environment variables or .env file for safety)
WEBUZO_API="https://your-webuzo-server:2003/index.php?api=json"
WEBUZO_USER="${WEBUZO_USER:-your_webuzo_username}"
WEBUZO_KEY="${WEBUZO_KEY:-your_webuzo_api_key}"

# Domain configuration
DOMAIN="yourdomain.com"
WILDCARD="*.${DOMAIN}"
EMAIL="your_email@example.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACME_SCRIPT="$SCRIPT_DIR/acme.sh"
ACME_DIR="$HOME/.acme.sh/${DOMAIN}"

###########################################################

if [ ! -f "$ACME_SCRIPT" ]; then
  echo "📥 Downloading acme.sh..."
  curl https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh -o "$ACME_SCRIPT"
  chmod +x "$ACME_SCRIPT"
fi

echo "🔧 Registering acme.sh account..."
"$ACME_SCRIPT" --set-default-ca --server letsencrypt
"$ACME_SCRIPT" --register-account -m "$EMAIL" --server letsencrypt

echo "🌐 Creating DNS API hook..."
DNS_HOOK="$HOME/.acme.sh/dns_webuzo.sh"

cat > "$DNS_HOOK" <<'EOF'
#!/bin/bash

dns_webuzo_add() {
  fulldomain="$1"
  txtvalue="$2"

  echo "[webuzo] Adding TXT for $fulldomain = $txtvalue"

  curl --insecure -s -X POST "${WEBUZO_API}&act=advancedns" \
    -d "apiuser=${WEBUZO_USER}" \
    -d "apikey=${WEBUZO_KEY}" \
    -d "add=1" \
    -d "domain=${DOMAIN}" \
    -d "name=_acme-challenge" \
    -d "ttl=600" \
    -d "selecttype=TXT" \
    -d "address=${txtvalue}"
}

dns_webuzo_rm() {
  fulldomain="$1"
  echo "[webuzo] Removing all TXT records for $fulldomain"

  response=$(curl --insecure -s -X POST "${WEBUZO_API}&act=advancedns" \
    -d "apiuser=${WEBUZO_USER}" \
    -d "apikey=${WEBUZO_KEY}" \
    -d "domain=${DOMAIN}")

  echo "$response" | jq -r '
    .dns_list | to_entries[] |
    select(.value.name == "_acme-challenge" and .value.type == "TXT") |
    .key
  ' | while read -r index; do
    curl --insecure -s -X POST "${WEBUZO_API}&act=advancedns" \
      -d "apiuser=${WEBUZO_USER}" \
      -d "apikey=${WEBUZO_KEY}" \
      -d "domain=${DOMAIN}" \
      -d "delete=${index}"
  done
}
EOF

chmod +x "$DNS_HOOK"

# Export credentials
export WEBUZO_API WEBUZO_USER WEBUZO_KEY DOMAIN

echo "📡 Issuing RSA certificate..."
"$ACME_SCRIPT" --issue --dns dns_webuzo -d "$DOMAIN" -d "$WILDCARD" \
  --keylength 2048 --server letsencrypt --dnssleep 30 --force

if [ $? -ne 0 ]; then
  echo "❌ Certificate issuance failed"
  exit 1
fi

CERT_FILE="$ACME_DIR/${DOMAIN}.cer"
KEY_FILE="$ACME_DIR/${DOMAIN}.key"
CA_FILE="$ACME_DIR/ca.cer"
FULLCHAIN_FILE="$ACME_DIR/fullchain.cer"

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" || ! -f "$CA_FILE" ]]; then
  echo "❌ Missing certificate files"
  exit 1
fi

echo "🔐 Installing certificate on Webuzo..."

curl --insecure -X POST "${WEBUZO_API}&act=install_cert" \
  -d "apiuser=${WEBUZO_USER}" \
  -d "apikey=${WEBUZO_KEY}" \
  -d "install_key=1" \
  -d "selectdomain=${DOMAIN}" \
  --data-urlencode "kpaste=$(<${KEY_FILE})" \
  --data-urlencode "cpaste=$(<${FULLCHAIN_FILE})" \
  --data-urlencode "bpaste=$(<${CA_FILE})"

echo "✅ Webuzo installation complete."

echo "📅 Verifying monthly cron job..."
SCRIPT_PATH="$(readlink -f "$0")"
CRON_ENTRY="0 3 1 * * bash $SCRIPT_PATH >> \$HOME/acme-webuzo.log 2>&1"

if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
  echo "✅ Cron already exists."
else
  (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
  echo "✅ Monthly cron added."
fi
