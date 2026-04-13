FROM alpine:latest

# Install dependencies (curl for CLI installation, bash/sh for script)
RUN apk add --no-cache curl bash jq

# Setup workspace
WORKDIR /app
COPY fetch-secrets.sh /app/fetch-secrets.sh
RUN chmod +x /app/fetch-secrets.sh

# Default Environment Variables
ENV SECRETS_PATH=/secrets \
    ENVIRONMENT=dev \
    CRON_SCHEDULE=""

# Create the output volume
VOLUME ["/secrets"]

ENTRYPOINT ["/app/fetch-secrets.sh"]