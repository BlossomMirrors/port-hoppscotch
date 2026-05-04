#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="com.hoppscotch.Hoppscotch.yml"
METADATA_FILE="com.hoppscotch.Hoppscotch.metainfo.xml"
REPO_URL="https://github.com/hoppscotch/releases/releases/download"

# Reads config, if exists
if [ -f "fetch.config.yml" ]; then
    ALLOW_PRERELEASE=$(grep -m1 'allow-prerelease:' fetch.config.yml | awk '{print $2}')
else
    ALLOW_PRERELEASE="false"
fi

# --- Fetch latest Hoppscotch tag ---
echo "   Fetching latest tag from GitHub API..."

LATEST_TAG=$(curl -s https://api.github.com/repos/hoppscotch/releases/tags \
  | jq -r 'map(select(.name != "vv26.3.0-0")) | .[0].name')

if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
  echo "   Failed to fetch latest version tag from GitHub."
  exit 1
fi

# Removes unnecessary 'v' chars at the beginning
# LATEST_TAG=${LATEST_TAG#v}
LATEST_VERSION=$(echo "$LATEST_TAG" | sed 's/^v*//')

# Prerelease hypothesis
IS_PRERELEASE="false"
if [[ "$LATEST_TAG" == *"beta"* || "$LATEST_TAG" == *"alpha"* ]]; then
    IS_PRERELEASE="true"
fi

echo "   Found Tag: $LATEST_TAG (Clean: $LATEST_VERSION)"

if [[ "$IS_PRERELEASE" == "true" ]]; then
  echo "   Latest release is a prerelease: $LATEST_VERSION"
else
  echo "   Latest release is a stable release: $LATEST_VERSION"
fi

# --- Detect OS for sed compatibility ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_INPLACE="sed -i ''"
else
  SED_INPLACE="sed -i"
fi

# --- Extract current version from manifest ---
CURRENT_VERSION=$(grep -Po 'releases/download/v*\K[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?' "$MANIFEST_FILE" | head -n1 || true)
CURRENT_DATE=$(date '+%Y-%m-%d')

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "   Warning: Could not detect current version. Forcing update..."
    CURRENT_VERSION="0.0.0"
fi

# --- Create temp file with version number ---
echo "version: $CURRENT_VERSION" > version.txt
echo "prerelease: $IS_PRERELEASE" >> version.txt

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
  echo "   Manifest already up to date ($CURRENT_VERSION). Checking SHA256..."
else
  echo "   Updating manifest from $CURRENT_VERSION → $LATEST_VERSION"
  # Finds 'releases/download/' and replaces everything until next sub-domain break
  $SED_INPLACE -E "s|(releases/download/)[^/]+|\1$LATEST_TAG|g" "$MANIFEST_FILE"
  # Updates XML manifest
  $SED_INPLACE -E "s|(<release version=[\"'])[^\"']+([^>]*>)|\1$LATEST_VERSION\2|g" "$METADATA_FILE"
  $SED_INPLACE -E "s|(<release date=[\"'])[0-9]{4}-[0-9]{2}-[0-9]{2}|\1$CURRENT_DATE|g" "$METADATA_FILE"
  
  # --- Update version number ---
  echo "version: $LATEST_VERSION" > version.txt
  echo "prerelease: $IS_PRERELEASE" >> version.txt
fi

# --- Compute new SHA256 ---
DOWNLOAD_URL="$REPO_URL/$LATEST_TAG/Hoppscotch_linux_x64.deb"
echo "   Downloading $DOWNLOAD_URL to compute sha256..."
TMP_FILE=$(mktemp)
HTTP_CODE=$(curl -L -s -w "%{http_code}" -o "$TMP_FILE" "$DOWNLOAD_URL")

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: Download failed with HTTP code $HTTP_CODE"
  echo "URL: $DOWNLOAD_URL"
  rm -f "$TMP_FILE"
  exit 1
fi

NEW_SHA256=$(sha256sum "$TMP_FILE" | awk '{print $1}')
rm -f "$TMP_FILE"

if [[ -z "$NEW_SHA256" ]]; then
  echo "   Failed to compute SHA256 checksum."
  exit 1
fi

echo "   New SHA256: $NEW_SHA256"

# --- Replace sha256 field in manifest ---
$SED_INPLACE -E "s/sha256: [a-f0-9]+/sha256: $NEW_SHA256/" "$MANIFEST_FILE"

# --- Skip if not changed ---
if git diff --quiet -- "$MANIFEST_FILE"; then
  echo "   No effective change detected, skipping commit."
  exit 0
fi
