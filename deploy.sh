#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/var/www/node-project/node-mysql-project"
APP_NAME="node-mysql-project"
BRANCH="main"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

fail() {
    log "ERROR: $*"
    exit 1
}

cd "$APP_DIR" || fail "Project directory not found."

if [[ $EUID -eq 0 ]]; then
    fail "Do not run this script with sudo. Run it as the project owner."
fi

log "Starting deployment..."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "This directory is not a Git repository."

CURRENT_BRANCH="$(git branch --show-current)"

[[ "$CURRENT_BRANCH" == "$BRANCH" ]] \
    || fail "Expected branch '$BRANCH', found '$CURRENT_BRANCH'."

if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "Local tracked changes detected. Commit or safely back them up first."
fi

log "Fetching latest code from GitHub..."

git fetch origin "$BRANCH" \
    || fail "Git fetch failed. Check GitHub access."

git merge-base --is-ancestor HEAD "origin/$BRANCH" \
    || fail "Local branch has diverged from or is ahead of origin/$BRANCH."

if ! git diff --quiet HEAD "origin/$BRANCH" --; then
    log "Updating code..."
    git merge --ff-only "origin/$BRANCH" \
        || fail "Fast-forward update failed."
else
    log "No tracked file changes detected."
fi

[[ -f package.json ]] || fail "package.json not found."

if [[ -f package-lock.json ]]; then
    log "Installing locked dependencies..."
    npm ci --omit=dev \
        || fail "Dependency installation failed."
else
    log "Installing dependencies..."
    npm install --omit=dev \
        || fail "Dependency installation failed."
fi

log "Checking PM2 application..."

if ! pm2 describe "$APP_NAME" >/dev/null 2>&1; then
    fail "PM2 application '$APP_NAME' not found. Start it manually first."
fi

log "Restarting application with PM2..."

pm2 restart "$APP_NAME" --update-env \
    || fail "PM2 restart failed."

if ! pm2 describe "$APP_NAME" | grep -q "online"; then
    pm2 logs "$APP_NAME" --lines 50 --nostream || true
    fail "Application may not be running correctly. Check PM2 status and logs."
fi

pm2 save

log "Deployment completed."
log "Current commit: $(git rev-parse --short HEAD)"
log "PM2 application: $APP_NAME"

