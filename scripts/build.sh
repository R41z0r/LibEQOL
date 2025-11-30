#!/bin/bash

ROOT_DIR=$(pwd)
WOW_ADDON_DIR="/Applications/World of Warcraft/_retail_/Interface/AddOns"
TARGET_DIR="$WOW_ADDON_DIR/LibEQOL"

VERSION=$(git describe --tags --always 2>/dev/null || echo "dev")

echo "Building LibEQOL version $VERSION"

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# Copy addon content
rsync -a --delete \
  --exclude ".git" \
  --exclude ".github" \
  --exclude ".vscode" \
  --exclude "docs" \
  --exclude "examples" \
  --exclude ".gitmodules" \
  --exclude "scripts" \
  "$ROOT_DIR/" "$TARGET_DIR/"

# Replace @project-version@ in TOC at destination
sed -i '' "s/@project-version@/$VERSION/" "$TARGET_DIR/LibEQOL.toc"

echo "Copied to $TARGET_DIR"
