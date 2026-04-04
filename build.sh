#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KCC="$SCRIPT_DIR/../krypton/kcc.sh"

echo "[1/2] Krypton to C..."
bash "$KCC" run.k > kprocview_tmp.c

echo "[2/2] C to exe..."
gcc kprocview_tmp.c -o kprocview -lm -w
rm -f kprocview_tmp.c

echo "Done! Run: ./kprocview [--sort cpu|mem|pid|name] [--refresh ms] [--no-color]"
