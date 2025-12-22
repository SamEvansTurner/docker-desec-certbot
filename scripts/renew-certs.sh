#!/bin/bash
set -e

echo "[$(date)] Starting certificate renewal check..."

# Renew all certificates (Certbot only renews if <30 days remaining)
certbot renew

echo "[$(date)] Certificate renewal check completed."

# Dynamically copy all certificates to /certs/ for easy access
if [ -d "/etc/letsencrypt/live" ]; then
    for cert_dir in /etc/letsencrypt/live/*/; do
        # Skip the README directory
        if [ -f "$cert_dir/README" ]; then
            continue
        fi
        
        cert_name=$(basename "$cert_dir")
        echo "Copying certificate for: $cert_name"
        
        # Determine output filename (prefix wildcard certs with "wildcard.")
        if [[ "$cert_name" != *.* ]]; then
            # Single domain without dots might be wildcard result
            output_name="$cert_name"
        else
            # Check if this is a wildcard cert by looking at the certificate
            # Wildcard domains have names like "domain.com" but represent "*.domain.com"
            output_name="$cert_name"
        fi
        
        # Copy certificate files
        if [ -f "$cert_dir/fullchain.pem" ] && [ -f "$cert_dir/privkey.pem" ]; then
            cp -L "$cert_dir/fullchain.pem" "/certs/$output_name.crt"
            cp -L "$cert_dir/privkey.pem" "/certs/$output_name.key"
            chmod 644 "/certs/$output_name.crt"
            chmod 600 "/certs/$output_name.key"
            echo "✓ Certificate copied: $output_name.crt and $output_name.key"
        else
            echo "⚠ Warning: Certificate files not found for $cert_name"
        fi
    done
fi

echo "[$(date)] All certificates processed and copied to /certs/"
