#!/bin/bash
set -e

echo "==================================================="
echo "Let's Encrypt Certificate Manager with deSEC"
echo "==================================================="
echo "Email: $EMAIL"
echo "Domains: $DOMAINS"
echo "Timezone: $TZ"
echo "Running as: $(id -u):$(id -g)"
echo "==================================================="

# Security warning if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo ""
    echo "⚠️  WARNING: Container is running as root user"
    echo "   For better security, consider using --user UID:GID"
    echo "   See README.md for non-root configuration instructions"
    echo ""
fi

# Function to check write permissions
check_permissions() {
    local dir=$1
    local test_file="${dir}/.permission_test_$$"
    
    if ! touch "$test_file" 2>/dev/null; then
        echo "ERROR: Cannot write to ${dir}"
        echo "This directory must be writable by user $(id -u):$(id -g)"
        echo ""
        echo "To fix this on the host:"
        echo "  sudo chown -R $(id -u):$(id -g) /path/to/$(basename ${dir})"
        echo ""
        echo "Or run container with a user that owns these directories:"
        echo "  --user \$(id -u):\$(id -g)"
        echo ""
        return 1
    fi
    rm -f "$test_file"
    return 0
}

# Check write permissions for critical directories
echo "Checking permissions..."
check_permissions "/etc/letsencrypt" || exit 1
check_permissions "/certs" || exit 1
echo "✓ All permissions OK"
echo ""

# Create subdirectories within volume mounts (after permission check)
mkdir -p /etc/letsencrypt/logs
mkdir -p /etc/letsencrypt/work

# Create credentials file from environment variable
CREDENTIALS_FILE="/etc/letsencrypt/desec-credentials.ini"

if [ -z "$DESEC_TOKEN" ]; then
    echo "ERROR: DESEC_TOKEN environment variable is required!"
    echo "Please set the DESEC_TOKEN environment variable with your deSEC API token."
    echo ""
    echo "Example:"
    echo "  docker run -e DESEC_TOKEN=your_token_here ..."
    exit 1
fi

echo "Using deSEC token from environment variable..."
echo "dns_desec_token = $DESEC_TOKEN" > "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"

# Parse comma-separated domains
IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"

# Request certificates for each domain
for domain in "${DOMAIN_ARRAY[@]}"; do
    domain=$(echo "$domain" | xargs)  # Trim whitespace
    
    # Create safe directory name for certificate storage
    if [[ "$domain" == *"*"* ]]; then
        # For *.services.example.com -> services.example.com
        cert_name="${domain//\*./}"
    else
        cert_name="$domain"
    fi
    
    echo "---------------------------------------------------"
    echo "Processing: $domain"
    echo "Certificate name: $cert_name"
    echo "---------------------------------------------------"
    
    if [ ! -d "/etc/letsencrypt/live/$cert_name" ]; then
        echo "Requesting NEW certificate for $domain..."
        certbot certonly \
          --authenticator dns-desec \
          --dns-desec-credentials /etc/letsencrypt/desec-credentials.ini \
          --non-interactive \
          --agree-tos \
          --email "$EMAIL" \
          --cert-name "$cert_name" \
          --logs-dir /etc/letsencrypt/logs \
          --work-dir /etc/letsencrypt/work \
          -d "$domain"
        
        if [ $? -eq 0 ]; then
            echo "✓ Certificate obtained successfully for $domain"
        else
            echo "✗ Failed to obtain certificate for $domain"
        fi
    else
        echo "✓ Certificate already exists for $domain"
    fi
done

echo "==================================================="
echo "Initial setup complete!"
echo "==================================================="

# Run initial renewal check and copy certificates
# Use tee to show output and log it
/usr/local/bin/renew-certs.sh 2>&1 | tee -a /etc/letsencrypt/logs/renewal.log

echo "==================================================="
echo "Starting automatic renewal service..."
echo "Certificates will be checked daily around 2:00 AM"
echo "==================================================="

# Sleep loop for daily renewal checks
while true; do
    # Calculate seconds until next 2 AM
    current_epoch=$(date +%s)
    target_epoch=$(date -d "tomorrow 02:00:00" +%s)
    sleep_seconds=$((target_epoch - current_epoch))
    
    echo "Next renewal check in $((sleep_seconds / 3600)) hours"
    sleep $sleep_seconds
    
    # Run renewal check with tee (show output and log)
    /usr/local/bin/renew-certs.sh 2>&1 | tee -a /etc/letsencrypt/logs/renewal.log
done
