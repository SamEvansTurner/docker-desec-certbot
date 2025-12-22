FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    certbot \
    py3-pip \
    dcron \
    bash \
    && pip3 install --no-cache-dir --break-system-packages certbot-dns-desec

# Create directories
# Ownership will be determined by the user running the container
RUN mkdir -p /etc/letsencrypt /var/log/letsencrypt /certs

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
