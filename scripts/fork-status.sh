#!/usr/bin/env bash
# fork-status.sh — how far this fork has drifted from upstream Postiz, and what a
# catch-up merge would actually cost. Run it before deciding to update; the answer
# is usually much smaller than the commit count suggests.
#
#   ./scripts/fork-status.sh            # summary
#   ./scripts/fork-status.sh --merge    # + dry-run merge, lists real conflicts
#
# Adds the `upstream` remote on first run. Read-only: the dry run happens in a
# throwaway worktree and never touches your checkout or any branch.
set -uo pipefail

UPSTREAM_URL=https://github.com/gitroomhq/postiz-app.git
UPSTREAM_BRANCH=upstream/main
WORKTREE=/tmp/fork-status-merge-$$

cd "$(git rev-parse --show-toplevel)" || exit 1

if ! git remote get-url upstream >/dev/null 2>&1; then
    echo "adding upstream remote -> $UPSTREAM_URL"
    git remote add upstream "$UPSTREAM_URL" || exit 1
fi

echo "fetching upstream..."
git fetch -q --tags upstream || { echo "fetch failed"; exit 1; }

base="$(git merge-base HEAD "$UPSTREAM_BRANCH")"
[ -n "$base" ] || { echo "no merge base with $UPSTREAM_BRANCH"; exit 1; }

echo
echo "fork point   : $(git log -1 --format='%h %ad' --date=short "$base")  (upstream tag: $(git describe --tags --abbrev=0 "$base" 2>/dev/null || echo unknown))"
echo "upstream now : $(git log -1 --format='%h %ad' --date=short "$UPSTREAM_BRANCH")  (latest tag: $(git describe --tags --abbrev=0 "$UPSTREAM_BRANCH" 2>/dev/null || echo unknown))"
echo "behind       : $(git rev-list --count "$base..$UPSTREAM_BRANCH") upstream commits"
echo "ahead        : $(git rev-list --count "$base..HEAD") local commits"
echo

ours="$(git diff --name-only "$base..HEAD" | sort)"
theirs="$(git diff --name-only "$base..$UPSTREAM_BRANCH" | sort)"
shared="$(comm -12 <(echo "$ours") <(echo "$theirs"))"

echo "files we changed        : $(echo "$ours" | grep -c .)"
echo "  of which upstream also changed (conflict surface): $(echo "$shared" | grep -c .)"
echo "  files only we touched (safe to carry)            : $(comm -23 <(echo "$ours") <(echo "$theirs") | grep -c .)"
echo "  brand-new files we added (zero merge risk)       : $(git diff --name-status "$base..HEAD" | grep -c '^A')"
echo

echo "provider changes upstream has that we do not:"
echo "  $(git rev-list --count "$base..$UPSTREAM_BRANCH" -- libraries/nestjs-libraries/src/integrations/social) commits under integrations/social"
echo "  (these are the ones that matter when a network's API shifts)"

if [ "${1:-}" != "--merge" ]; then
    echo
    echo "run with --merge to dry-run the catch-up and list real conflicts"
    exit 0
fi

echo
echo "dry-run merging $UPSTREAM_BRANCH into HEAD (throwaway worktree)..."
git worktree add -f "$WORKTREE" "$UPSTREAM_BRANCH" >/dev/null 2>&1 || {
    echo "could not create worktree"; exit 1; }
(
    cd "$WORKTREE" || exit 1
    git merge --no-commit --no-ff "$(git -C "$OLDPWD" rev-parse HEAD)" >/dev/null 2>&1
    conflicts="$(git diff --name-only --diff-filter=U)"
    n="$(echo "$conflicts" | grep -c .)"
    echo
    echo "REAL CONFLICTS: $n"
    [ "$n" -gt 0 ] && echo "$conflicts" | sed 's/^/  /'
    git merge --abort >/dev/null 2>&1
)
git worktree remove -f "$WORKTREE" >/dev/null 2>&1
echo
echo "See FORK.md for what each recurring conflict file customises."
