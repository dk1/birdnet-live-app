#!/usr/bin/env bash
# =============================================================================
# Species Bundle Toggle
# =============================================================================
#
# The full species image/description bundle adds ~10k WebP photos to the
# app, which meaningfully slows Gradle asset packaging and `adb install`.
# This lets you build it once and cheaply toggle it in/out of assets/ for
# "final" long-term-testing builds vs. fast everyday dev builds.
#
# Usage:
#   tools/species_bundle.sh build   # slow: download + resize, then cache it
#   tools/species_bundle.sh on      # fast: restore the full bundle into assets/
#   tools/species_bundle.sh off     # fast: back to the lightweight default
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$ROOT/tools/.cache/species_bundle_full"
IMAGES_DIR="$ROOT/assets/species_images"
DATA_DIR="$ROOT/assets/species_data"
TAXONOMY_CSV="$ROOT/assets/models/taxonomy.csv"

cmd="${1:-}"

case "$cmd" in
  build)
    if [ ! -f "$ROOT"/tools/data/birdnet_taxonomy*.json 2>/dev/null ] && \
       [ -z "$(ls "$ROOT"/tools/data/birdnet_taxonomy*.json 2>/dev/null)" ]; then
      echo "Downloading taxonomy JSON..."
      "$ROOT/tools/.venv/bin/python" "$ROOT/tools/download_taxonomy_json.py"
    fi
    echo "Building species bundle (this downloads/resizes ~10k images)..."
    "$ROOT/tools/.venv/bin/python" "$ROOT/tools/build_species_bundle.py"

    echo "Caching bundle to $CACHE_DIR for fast on/off toggling..."
    rm -rf "$CACHE_DIR"
    mkdir -p "$CACHE_DIR"
    cp -R "$IMAGES_DIR" "$CACHE_DIR/species_images"
    cp -R "$DATA_DIR" "$CACHE_DIR/species_data"
    cp "$TAXONOMY_CSV" "$CACHE_DIR/taxonomy.csv"
    echo "Done. Use 'tools/species_bundle.sh on' / 'off' to toggle it from now on."
    ;;

  on)
    if [ ! -d "$CACHE_DIR" ]; then
      echo "No cached bundle found. Run 'tools/species_bundle.sh build' first." >&2
      exit 1
    fi
    echo "Restoring full species bundle into assets/..."
    rm -rf "$IMAGES_DIR" "$DATA_DIR"
    cp -R "$CACHE_DIR/species_images" "$IMAGES_DIR"
    cp -R "$CACHE_DIR/species_data" "$DATA_DIR"
    cp "$CACHE_DIR/taxonomy.csv" "$TAXONOMY_CSV"
    echo "Done. Full bundle is in place — expect a bigger, slower build."
    ;;

  off)
    echo "Restoring lightweight default (dummy.webp only, no species_data)..."
    rm -rf "$IMAGES_DIR" "$DATA_DIR"
    mkdir -p "$IMAGES_DIR"
    if [ -f "$CACHE_DIR/species_images/dummy.webp" ]; then
      cp "$CACHE_DIR/species_images/dummy.webp" "$IMAGES_DIR/dummy.webp"
    else
      git -C "$ROOT" checkout -- assets/species_images/dummy.webp
    fi
    git -C "$ROOT" checkout -- assets/models/taxonomy.csv
    echo "Done. Back to the fast default build."
    ;;

  *)
    echo "Usage: tools/species_bundle.sh {build|on|off}" >&2
    exit 1
    ;;
esac
