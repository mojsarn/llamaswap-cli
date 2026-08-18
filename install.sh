#!/usr/bin/env bash
# Deploy the tools in bin/ to /usr/local/bin (root-owned, mode 755).
#
#   ./install.sh          install, after showing what would change
#   ./install.sh --check  report drift only, change nothing (exit 1 if drift)
#   ./install.sh --pull   copy the LIVE /usr/local/bin versions back into bin/
#                         (use when someone edited the deployed copy directly)
set -uo pipefail

DEST=/usr/local/bin
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin"
TOOLS=(llm llm-plan llm-addmodel llm-url gpu-stat llama-server-sycl llama-server-vulkan)

MODE=install
case "${1:-}" in
  --check) MODE=check ;;
  --pull)  MODE=pull ;;
  "")      ;;
  *) echo "usage: $0 [--check|--pull]"; exit 1 ;;
esac

if [ "$MODE" = pull ]; then
  for t in "${TOOLS[@]}"; do
    if [ -f "$DEST/$t" ] && ! cmp -s "$DEST/$t" "$SRC/$t"; then
      cp "$DEST/$t" "$SRC/$t"
      echo "pulled $t from $DEST"
    fi
  done
  chmod 755 "$SRC"/*
  echo "done - review with 'git diff' before committing"
  exit 0
fi

DRIFT=0
for t in "${TOOLS[@]}"; do
  if [ ! -f "$SRC/$t" ]; then
    echo "MISSING IN REPO: $t"; DRIFT=1; continue
  fi
  if [ ! -f "$DEST/$t" ]; then
    echo "not installed:   $t"; DRIFT=1
  elif ! cmp -s "$SRC/$t" "$DEST/$t"; then
    echo "differs:         $t"; DRIFT=1
  fi
done

if [ "$DRIFT" = 0 ]; then
  echo "in sync - nothing to do"
  exit 0
fi

if [ "$MODE" = check ]; then
  echo
  echo "run './install.sh' to deploy, or './install.sh --pull' to adopt the live versions"
  exit 1
fi

# Syntax-check the bash scripts before putting them somewhere root runs them.
for t in llm gpu-stat llama-server-sycl llama-server-vulkan; do
  bash -n "$SRC/$t" || { echo "SYNTAX ERROR in $t - aborting"; exit 1; }
done
for t in llm-plan llm-addmodel llm-url; do
  python3 -m py_compile "$SRC/$t" || { echo "SYNTAX ERROR in $t - aborting"; exit 1; }
done
rm -rf "$SRC/__pycache__"

echo
for t in "${TOOLS[@]}"; do
  sudo install -o root -g root -m 755 "$SRC/$t" "$DEST/$t"
  echo "installed $t"
done
echo "done"
