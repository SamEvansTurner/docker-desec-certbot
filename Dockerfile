FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    certbot \
    py3-pip \
    bash \
    tzdata \
    && pip3 install --no-cache-dir --break-system-packages certbot-dns-desec

# Note: Volume mount directories (/etc/letsencrypt, /certs) are created automatically by Docker
# Subdirectories are created at runtime in entrypoint.sh

# Copy scripts
COPY scripts/renew-certs.sh /usr/local/bin/renew-certs.sh
COPY scripts/entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/renew-certs.sh /entrypoint.sh

# Default environment variables (MUST be overridden at runtime)
ENV EMAIL=""
ENV DOMAINS=""
ENV DESEC_TOKEN=""
ENV TZ=UTC

# Expose volumes for persistent data
VOLUME ["/etc/letsencrypt", "/certs"]

ENTRYPOINT ["/entrypoint.sh"]
