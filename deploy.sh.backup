#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/var/www/node-project/node-mysql-project"
SERVICE_NAME="node-mysql-project"
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

# Verify Git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "This directory is not a Git repository."

# Verify the expected branch
CURRENT_BRANCH="$(git branch --show-current)"

[[ "$CURRENT_BRANCH" == "$BRANCH" ]] \
    || fail "Expected branch '$BRANCH', found '$CURRENT_BRANCH'."

# Ensure local tracked files do not contain uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "Local tracked changes detected. Commit or safely back them up first."
fi

# Fetch latest changes from GitHub
log "Fetching latest code from GitHub..."
git fetch origin "$BRANCH" \
    || fail "Git fetch failed. Check network and GitHub access."

# Do not overwrite local commits or create an accidental merge
git merge-base --is-ancestor HEAD "origin/$BRANCH" \
    || fail "Local branch has diverged from or is ahead of origin/$BRANCH."

if git diff --quiet HEAD "origin/$BRANCH" --; then
    log "No tracked file changes detected."
else
    log "Updating code to the latest GitHub commit..."
    git merge --ff-only "origin/$BRANCH" \
        || fail "Fast-forward update failed."
fi

# Verify required Node.js project files
[[ -f package.json ]] || fail "package.json not found."

# Install dependencies reproducibly when a lockfile exists
if [[ -f package-lock.json ]]; then
    log "Installing locked dependencies..."
    npm ci --omit=dev \
        || fail "Dependency installation failed."
else
    log "No package-lock.json found; using npm install..."
    npm install --omit=dev \
        || fail "Dependency installation failed."
fi

# Restart the application
log "Restarting application service..."
sudo systemctl restart "$SERVICE_NAME" \
    || fail "Service restart failed."

# Confirm the service is running
if ! sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    sudo journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    fail "Application service is not active."
fi

log "Deployment completed successfully."
log "Current commit: $(git rev-parse --short HEAD)"
log "Application service: $SERVICE_NAME"

exit 0
