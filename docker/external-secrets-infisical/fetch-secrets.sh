#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
INFISICAL_API_URL="${INFISICAL_API_URL:-https://app.infisical.com}"
INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:?Variable INFISICAL_UNIVERSAL_AUTH_CLIENT_ID is required}"
INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:?Variable INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET is required}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:?Variable INFISICAL_PROJECT_ID is required}"
INFISICAL_ORGANIZATION_SLUG="${INFISICAL_ORGANIZATION_SLUG:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
SECRETS_PATH="${SECRETS_PATH:-/secrets}"
CRON_SCHEDULE="${CRON_SCHEDULE:-}"

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# ── Core logic ────────────────────────────────────────────────────────────────
fetch_secrets() {
    log "Authenticating with Infisical (${INFISICAL_API_URL})..."

    local auth_body
    auth_body=$(printf '{"clientId":"%s","clientSecret":"%s"' \
        "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID}" \
        "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET}")
    if [ -n "${INFISICAL_ORGANIZATION_SLUG}" ]; then
        auth_body="${auth_body},\"organizationSlug\":\"${INFISICAL_ORGANIZATION_SLUG}\""
    fi
    auth_body="${auth_body}}"

    local auth_response
    auth_response=$(curl -sSf -X POST \
        "${INFISICAL_API_URL}/api/v1/auth/universal-auth/login" \
        -H "Content-Type: application/json" \
        -d "${auth_body}")

    local access_token
    access_token=$(printf '%s' "${auth_response}" | jq -r '.accessToken // empty')
    if [ -z "${access_token}" ]; then
        log "ERROR: Authentication failed." >&2
        log "Response: ${auth_response}" >&2
        return 1
    fi

    log "Fetching secrets (project=${INFISICAL_PROJECT_ID}, env=${ENVIRONMENT})..."

    local secrets_response
    secrets_response=$(curl -sSf -G \
        "${INFISICAL_API_URL}/api/v4/secrets" \
        --data-urlencode "projectId=${INFISICAL_PROJECT_ID}" \
        --data-urlencode "environment=${ENVIRONMENT}" \
        --data-urlencode "secretPath=/" \
        --data-urlencode "recursive=true" \
        --data-urlencode "viewSecretValue=true" \
        --data-urlencode "expandSecretReferences=true" \
        -H "Authorization: Bearer ${access_token}")

    local secret_count
    secret_count=$(printf '%s' "${secrets_response}" | jq '.secrets | length')
    log "Writing ${secret_count} secret(s) to ${SECRETS_PATH}..."

    printf '%s' "${secrets_response}" | jq -r '[.secrets[].secretPath] | unique[]' | while IFS= read -r folder; do
        local folder_norm output_file output_dir
        folder_norm="${folder%/}"
        if [ -z "${folder_norm}" ]; then
            output_file="${SECRETS_PATH}/_root"
        else
            output_file="${SECRETS_PATH}${folder_norm}"
        fi
        output_dir=$(dirname "${output_file}")
        mkdir -p "${output_dir}"

        printf '%s' "${secrets_response}" | jq -r --arg path "${folder}" \
            '.secrets[] | select(.secretPath == $path) | "\(.secretKey)=\(.secretValue // "")"' \
            > "${output_file}"
        log "  Wrote ${output_file}"
    done

    log "Secrets sync complete."
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

# When called by crond, skip cron setup and run directly.
if [ "${1:-}" = "--run-once" ]; then
    fetch_secrets
    exit 0
fi

if [ -n "${CRON_SCHEDULE}" ]; then
    log "Scheduling periodic sync: '${CRON_SCHEDULE}'"

    # Persist credentials to a protected env file for use by crond.
    cat > /app/env.sh <<ENVEOF
export INFISICAL_API_URL='${INFISICAL_API_URL}'
export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID='${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID}'
export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET='${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET}'
export INFISICAL_PROJECT_ID='${INFISICAL_PROJECT_ID}'
export INFISICAL_ORGANIZATION_SLUG='${INFISICAL_ORGANIZATION_SLUG}'
export ENVIRONMENT='${ENVIRONMENT}'
export SECRETS_PATH='${SECRETS_PATH}'
ENVEOF
    chmod 600 /app/env.sh

    # Write crontab; redirect output to PID 1's stdout so it appears in docker logs.
    printf '%s\t. /app/env.sh && /app/fetch-secrets.sh --run-once >> /proc/1/fd/1 2>&1\n' \
        "${CRON_SCHEDULE}" > /etc/crontabs/root

    fetch_secrets
    exec crond -f -l 2
else
    fetch_secrets
fi