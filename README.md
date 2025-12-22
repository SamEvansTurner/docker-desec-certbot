# Let's Encrypt Certificate Manager with deSEC

Automated Let's Encrypt SSL certificate management using Certbot and deSEC DNS. Supports any domain configuration including single domains, multiple domains, and wildcard certificates.

## Features

- ✅ Automatic certificate requests for any domains you specify
- ✅ DNS-01 challenge via deSEC (no public web server required)
- ✅ Support for wildcard certificates (*.yourdomain.com)
- ✅ Automatic daily renewal checks
- ✅ Certificates exported to `/certs/` for easy access
- ✅ **Secure environment variable configuration**
- ✅ **Runs as non-root user for enhanced security**
- ✅ Alpine-based Docker image (~50MB)
- ✅ Docker Compose support with `.env` file

## Prerequisites

1. **Domain registered** with nameservers pointing to deSEC:
   - `ns1.desec.io`
   - `ns2.desec.io`
   - Note: A records are not required for certificate issuance (see [DNS Configuration](#dns-configuration))

2. **deSEC account** and API token from https://desec.io/

3. **Docker** (and optionally Docker Compose) installed on your server

## Quick Start

### Docker Compose (Recommended)

```bash
# 1. Clone repository
git clone https://github.com/SamEvansTurner/docker-desec-certbot.git
cd docker-desec-certbot

# 2. Configure environment
cp .env.example .env
nano .env  # Add your email, domains, and deSEC token

# 3. Set up user and permissions
MY_UID=$(id -u)
MY_GID=$(id -g)
# Edit docker-compose.yml and update user: line with your UID:GID

# 4. Create directories
mkdir -p letsencrypt certs
sudo chown -R $MY_UID:$MY_GID letsencrypt certs

# 5. Start container
docker-compose up -d
docker-compose logs -f
```

### Docker Run

```bash
# Set up directories
mkdir -p ~/certbot-desec/{letsencrypt,certs}
sudo chown -R $(id -u):$(id -g) ~/certbot-desec

# Run container
docker run -d \
  --name certbot-desec \
  --restart unless-stopped \
  --user $(id -u):$(id -g) \
  -e EMAIL=admin@yourdomain.com \
  -e DOMAINS=yourdomain.com,*.services.yourdomain.com \
  -e DESEC_TOKEN=your_desec_token_here \
  -e TZ=UTC \
  -v ~/certbot-desec/letsencrypt:/etc/letsencrypt \
  -v ~/certbot-desec/certs:/certs \
  ghcr.io/samevansturner/docker-desec-certbot:latest
```

## Configuration

### Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `EMAIL` | **Yes** | Email for Let's Encrypt notifications | `admin@yourdomain.com` |
| `DOMAINS` | **Yes** | Comma-separated list of domains | `yourdomain.com,*.services.yourdomain.com` |
| `DESEC_TOKEN` | **Yes** | Your deSEC API token from https://desec.io/ | `your_token_here` |
| `TZ` | No | Timezone for logs | `UTC` (default) |

### Domain Examples

```bash
# Single domain
DOMAINS=yourdomain.com

# Multiple domains
DOMAINS=yourdomain.com,www.yourdomain.com,api.yourdomain.com

# Wildcard certificate
DOMAINS=*.yourdomain.com

# Mixed
DOMAINS=yourdomain.com,*.services.yourdomain.com
```

### Certificate Output

Certificates are automatically copied to `/certs/` with user-friendly names:

```
~/certbot-desec/certs/
├── yourdomain.com.crt              # Certificate
├── yourdomain.com.key              # Private key
├── services.yourdomain.com.crt     # Wildcard cert (*.services.yourdomain.com)
└── services.yourdomain.com.key     # Wildcard private key
```

**Note:** Wildcard domain names have the `*.` prefix removed by Certbot (e.g., `*.services.example.com` becomes `services.example.com`).

### DNS Configuration

**Note:** DNS A records are not required for obtaining certificates. The DNS-01 challenge only uses temporary TXT records which Certbot creates automatically. However, you'll need A records configured when you want to serve content from these domains.

Add A records in your deSEC DNS panel:

```
yourdomain.com                    A    YOUR_SERVER_IP
*.services.yourdomain.com         A    YOUR_SERVER_IP
```

## User & Security Configuration

### Running as Non-Root (Recommended)

The container supports running as any user ID for enhanced security. This follows the principle of least privilege and ensures certificate files are owned by your user.

**Find your user ID:**
```bash
id -u  # Your UID (e.g., 1000)
id -g  # Your GID (e.g., 1000)
```

**Configure the user:**
- **Docker Compose:** Update `user:` line in `docker-compose.yml` with your UID:GID
- **Docker Run:** Add `--user $(id -u):$(id -g)` flag

**Set directory permissions:**
```bash
sudo chown -R YOUR_UID:YOUR_GID letsencrypt certs
```

**Using a different existing user:**
```bash
# Example: Using 'certmanager' service user
SERVICE_UID=$(id -u certmanager)
SERVICE_GID=$(id -g certmanager)
sudo chown -R $SERVICE_UID:$SERVICE_GID letsencrypt certs

# Update docker-compose.yml
user: "1005:1005"  # Replace with actual UID:GID
```

### Running as Root (Not Recommended)

The container can run as root if you omit the `--user` flag or comment out `user:` in docker-compose.yml.

**Implications:**
- ⚠️ Security risk (violates principle of least privilege)
- Certificate files owned by root on host
- Requires `sudo` to access certificates
- You'll see a warning at container startup

**Only use root for:**
- Quick testing/development
- When you understand and accept the security risks

## Automatic Renewal

- Checks daily at **2:00 AM**
- Renews certificates with **<30 days remaining**
- Certificates automatically copied to `/certs/`
- No manual intervention required

## Management Commands

```bash
# View logs
docker-compose logs -f
# or: docker logs -f certbot-desec

# Check certificate expiry
docker-compose exec certbot-desec certbot certificates

# Force renewal (testing)
docker-compose exec certbot-desec certbot renew --force-renewal

# Restart
docker-compose restart
# or: docker restart certbot-desec

# Stop
docker-compose down
# or: docker stop certbot-desec
```

## Security Best Practices

This project implements multiple security features:

- **Non-root execution** - Runs with minimal privileges
- **Environment variable credentials** - No files on host filesystem
- **Automatic key permissions** - Private keys set to `chmod 600`
- **Git safety** - `.env` automatically ignored
- **Minimal image** - Alpine-based (~50MB)

**Security checklist:**
- ✅ Run as non-root user
- ✅ Use environment variables for credentials
- ✅ Never commit `.env` or credentials to git
- ✅ Rotate deSEC tokens periodically
- ✅ Use strong, unique tokens

## Troubleshooting

### Permission Errors

```bash
# Check ownership
ls -la letsencrypt certs

# Fix ownership
sudo chown -R $(id -u):$(id -g) letsencrypt certs
```

### Container Won't Start

```bash
# Check logs for errors
docker logs certbot-desec

# Verify environment variables are set
docker exec certbot-desec env | grep -E 'EMAIL|DOMAINS|DESEC_TOKEN'
```

### Certificate Not Generated

```bash
# Check certificate status
docker exec certbot-desec certbot certificates

# Verify certificate directories
docker exec certbot-desec ls -la /etc/letsencrypt/live/

# Test DNS-01 challenge (dry run)
docker exec certbot-desec certbot certonly \
  --dns-desec \
  --dns-desec-credentials /etc/letsencrypt/desec-credentials.ini \
  --dry-run \
  -d yourdomain.com
```

### View Renewal Logs

```bash
docker exec certbot-desec cat /etc/letsencrypt/logs/renewal.log
```

## Updating

```bash
# Docker Compose
docker-compose pull
docker-compose up -d

# Docker Run
docker pull ghcr.io/samevansturner/docker-desec-certbot:latest
docker stop certbot-desec
docker rm certbot-desec
# Re-run with same command from Quick Start
```

## Development

### Local Build

```bash
git clone https://github.com/SamEvansTurner/docker-desec-certbot.git
cd docker-desec-certbot
docker build -t docker-desec-certbot .
```

### CI/CD

GitHub Actions automatically:
- Builds image on push to `main`
- Pushes to GitHub Container Registry (GHCR)
- Tags as `latest` and by commit SHA

## Support

- **This project**: [GitHub Issues](https://github.com/SamEvansTurner/docker-desec-certbot/issues)
- **deSEC**: https://desec.io/
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **Certbot**: https://certbot.eff.org/docs/
