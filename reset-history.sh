#!/usr/bin/env bash
# Squashes all git history to a single commit and compacts the repo.
# Run from the repository root:
#   bash reset-history.sh
set -euo pipefail

BRANCH="main"
COMMIT_MSG="chore: fresh catalog templates (history reset)

Replaces all generated templates with latest output.
Repository history was reset to keep the repo size small."

echo "=== Shopware Catalog Templates — History Reset ==="
echo ""
echo "This will squash ALL git history on '$BRANCH' to a single commit."
echo "Working directory: $(pwd)"
echo ""
read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# 1. Remove this script before committing so it isn't included in the snapshot
echo ""
echo "=== Removing reset script ==="
rm -f "${BASH_SOURCE[0]}"

# 2. Create orphan branch (no history)
echo "=== Creating orphan branch ==="
git checkout --orphan tmp-reset

# 3. Stage everything (script is already deleted from disk)
git add -A

# 4. Commit the clean snapshot
echo "=== Committing fresh snapshot ==="
git commit -m "$COMMIT_MSG"

# 5. Rename orphan branch to main (replaces old main)
echo "=== Replacing $BRANCH with new single-commit history ==="
git branch -M "$BRANCH"

# 6. Delete any backup refs left by this or previous resets (e.g. refs/tmp/pre-rewrite-main)
echo "=== Cleaning up stale backup refs ==="
git for-each-ref --format='%(refname)' refs/tmp/ 2>/dev/null | while IFS= read -r ref; do
  echo "  Deleting $ref"
  git update-ref -d "$ref"
done

# 7. Update remote tracking ref so it doesn't hold old objects
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  echo "=== Updating origin/$BRANCH tracking ref ==="
  git update-ref "refs/remotes/origin/$BRANCH" "refs/heads/$BRANCH"
fi

# 8. Expire reflog so old commits can be pruned
echo "=== Expiring reflog ==="
git reflog expire --expire=now --all

# 9. Replace the pack with a minimal clone (avoids --aggressive slowness on binary files)
echo "=== Repacking (lean clone strategy) ==="
TMPDIR_LEAN="$(mktemp -d)"
git clone --no-local --bare "file://$(pwd)" "$TMPDIR_LEAN/lean.git" 2>/dev/null
rm -f .git/objects/pack/*.pack .git/objects/pack/*.idx .git/objects/pack/*.rev
cp "$TMPDIR_LEAN/lean.git/objects/pack/"* .git/objects/pack/
rm -rf "$TMPDIR_LEAN"

echo ""
echo "=== Done ==="
echo "  .git size:       $(du -sh .git | cut -f1)"
echo "  generated/ size: $(du -sh generated/ | cut -f1)"
echo "  Commits:         $(git rev-list --count HEAD)"
echo ""
echo "To push (force required since history was rewritten):"
echo "  git push --force origin $BRANCH"
