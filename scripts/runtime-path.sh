#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# scripts/runtime-path.sh — Shared Flatpak runtime path definitions
# Source this file from installer, verifier, diagnostics, and rollback scripts.
# SERVER_PATH is an absolute path that must be visible inside the Stremio
# Flatpak sandbox. The app-owned per-user directory is the canonical location.

APP_ID="${APP_ID:-com.stremio.Stremio}"
HOME_DIR="$(cd "${HOME}" && pwd -P)"

# Canonical host path and persisted SERVER_PATH. Flatpak exposes the app-owned
# per-user directory to com.stremio.Stremio, which is the location proven by
# the Fedora/KDE incident evidence to be executable by the launcher.
CANONICAL_WRAPPER_DIR="${HOME_DIR}/.var/app/${APP_ID}/.stremio-server"
CANONICAL_WRAPPER="${CANONICAL_WRAPPER_DIR}/server-wrapper.js"
EXPECTED_SERVER_PATH="${CANONICAL_WRAPPER}"

# Historical v1.2.3 host-side staging location. It is not runtime-visible in
# the affected Flatpak installation and must not remain selectable.
LEGACY_WRAPPER="${HOME_DIR}/.stremio-server/server-wrapper.js"
LEGACY_WRAPPER_DIR="${HOME_DIR}/.stremio-server"

OVERRIDE_FILE="${HOME_DIR}/.local/share/flatpak/overrides/${APP_ID}"
