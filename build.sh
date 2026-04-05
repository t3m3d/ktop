#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KCC="$SCRIPT_DIR/../krypton/kcc.sh"

echo "[1/3] Selecting Linux platform..."
cp platform_linux.k platform.k

echo "[2/3] Krypton to C..."
bash "$KCC" --headers "$SCRIPT_DIR/../krypton/headers" run.k > ktop_tmp.c

echo "[3/3] C to exe..."
gcc ktop_tmp.c -I. -o ktop -lm -w
rm -f ktop_tmp.c platform.k

echo "Done! Run: ./ktop [--sort cpu|mem|pid|name] [--refresh ms] [--no-color]"
