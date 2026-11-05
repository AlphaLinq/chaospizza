#!/usr/bin/env bash
# Egyszeri: a helyi mappából Git-repó lesz (Claude git-történetével), push a
# GitHubra, majd az issue-k létrehozása. A Macen kell futtatni, ahol a git
# SSH-kulcs és a `gh auth login` már be van állítva.
#
#   bash tools/publish_github.sh            # alapértelmezett bundle: ../chaospizza.bundle
#   bash tools/publish_github.sh --issues   # csak az issue-k (ha a push már megvolt)
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="AlphaLinq/chaospizza"
BUNDLE="../chaospizza.bundle"

if [ "${1:-}" != "--issues" ]; then
  if [ ! -d .git ]; then
    [ -f "$BUNDLE" ] || { echo "Nincs meg a $BUNDLE fájl"; exit 1; }
    git init -b main
    git fetch "$BUNDLE" main:refs/remotes/bundle/main
    # A munkakönyvtár fájljai maradnak; csak a történet jön a bundle-ből.
    git reset --mixed refs/remotes/bundle/main
    # Files only in the history (e.g. .github templates that could not be
    # copied into this folder) are restored instead of being deleted.
    git ls-files -d -z | xargs -0 -r git checkout --
  fi
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Sync working tree (Codex + Studio changes since the bundle)"
  fi
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "git@github.com:${REPO}.git"
  if [ -n "$(git ls-remote --heads origin main 2>/dev/null)" ]; then
    echo "A GitHub-repóban már van main ág. Nem írom felül."
    echo "Ha az üres (pl. csak README), futtasd:  git pull --rebase origin main  majd újra ezt a scriptet."
    exit 1
  fi
  git push -u origin main
fi

gh auth status >/dev/null
python3 tools/create_backlog.py --repo "$REPO"
echo "Kész: https://github.com/${REPO}/issues"
