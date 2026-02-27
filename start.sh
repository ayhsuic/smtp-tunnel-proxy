#!/bin/bash
set -e

# Directory for configuration and persistent state in Zeabur
CONFIG_DIR="/data"
mkdir -p "$CONFIG_DIR"

# Variables provided by Zeabur or user
# Zeabur often sets ZEABUR_WEB_URL when a domain is bound
DOMAIN="${DOMAIN_NAME:-${ZEABUR_WEB_URL:-localhost}}"
PORT="${PORT:-587}"

echo "Starting setup for domain: $DOMAIN on port: $PORT"

# Ensure symlinks to /etc/smtp-tunnel for scripts that might hardcode the path
mkdir -p /etc/smtp-tunnel
ln -sf "$CONFIG_DIR/config.yaml" /etc/smtp-tunnel/config.yaml
ln -sf "$CONFIG_DIR/users.yaml" /etc/smtp-tunnel/users.yaml
ln -sf "$CONFIG_DIR/server.crt" /etc/smtp-tunnel/server.crt
ln -sf "$CONFIG_DIR/server.key" /etc/smtp-tunnel/server.key
ln -sf "$CONFIG_DIR/ca.crt" /etc/smtp-tunnel/ca.crt

# Generate config.yaml if it doesn't exist
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    echo "Creating default config.yaml..."
    cat > "$CONFIG_DIR/config.yaml" << EOF
server:
  host: "0.0.0.0"
  port: $PORT
  hostname: "$DOMAIN"
  cert_file: "$CONFIG_DIR/server.crt"
  key_file: "$CONFIG_DIR/server.key"
  users_file: "$CONFIG_DIR/users.yaml"
  log_users: true

client:
  server_host: "$DOMAIN"
  server_port: $PORT
  socks_port: 1080
  socks_host: "127.0.0.1"
  ca_cert: "ca.crt"
EOF
fi

# Generate users.yaml if it doesn't exist
if [ ! -f "$CONFIG_DIR/users.yaml" ]; then
    echo "Creating empty users.yaml..."
    cat > "$CONFIG_DIR/users.yaml" << EOF
users: {}
EOF
fi

# Generate certificates if they don't exist
if [ ! -f "$CONFIG_DIR/server.crt" ] || [ ! -f "$CONFIG_DIR/server.key" ]; then
    echo "Generating TLS certificates for $DOMAIN..."
    cd /app
    python3 generate_certs.py --hostname "$DOMAIN" --output-dir "$CONFIG_DIR"
fi

# Link ca.crt to /app so adduser script can bundle it
ln -sf "$CONFIG_DIR/ca.crt" /app/ca.crt

# Handle initial user creation if INITIAL_USER is provided
if [ -n "$INITIAL_USER" ]; then
    # We check if the user is already in users.yaml
    if ! grep -q "$INITIAL_USER" "$CONFIG_DIR/users.yaml"; then
        echo "Creating initial user: $INITIAL_USER..."
        cd /app
        # Run the adduser script
        python3 smtp-tunnel-adduser "$INITIAL_USER"
        
        # Package might be generated in /app, move it to /data 
        if [ -f "/app/${INITIAL_USER}.zip" ]; then
            mv "/app/${INITIAL_USER}.zip" "$CONFIG_DIR/"
            echo "Client connection package saved to: $CONFIG_DIR/${INITIAL_USER}.zip"
        fi
    fi
fi

# Start the server
echo "Starting SMTP Tunnel Proxy Server..."
cd /app
exec python3 server.py -c "$CONFIG_DIR/config.yaml"
