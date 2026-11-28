#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Hearth contributors
# SPDX-License-Identifier: AGPL-3.0-only
#
# Makes the public copy of this repository.
#
# The working repository keeps its own notes under private/ (decisions about
# one installation, test records, screenshots of test documents). Those never
# leave it. The public copy is a branch named "public" in which every commit
# is a snapshot of main without private/:
#
#   upstream history ... o---o---o        (unchanged, upstream's own commits)
#                                 \
#   public                         S1---S2---S3   (snapshots made here)
#
# A snapshot holds main's files at that moment, minus private/. Its parents
# are the previous snapshot and, when main has taken a newer upstream commit
# since, that upstream commit, so upstream's history stays intact and
# shareable while nothing of main's own history (which did contain private
# files) is ever published. Only the snapshot's tree is new content, so that
# tree is all a secret scan has to cover.
#
# Usage: hearth/export-public.sh            make a snapshot if main changed
#        hearth/export-public.sh --check    print what the snapshot would
#                                           leave out and stop
# It never pushes. Push refs/heads/public to the public remote's hearth
# branch after the scan:  git push github public:hearth
#
# HEARTH_MAIN_REF names the commit to snapshot (default: the local branch
# main). Work done in a worktree is pushed to origin's main, and the local
# main may be checked out elsewhere and behind: HEARTH_MAIN_REF=origin/main
# after a fetch snapshots what was pushed.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
private_dir="private"
upstream_ref="${HEARTH_UPSTREAM_REF:-upstream/main}"
main_ref="${HEARTH_MAIN_REF:-main}"

if [ "${1:-}" = "--check" ]; then
    git ls-tree -r --name-only "$main_ref" -- "$private_dir" | sed 's/^/left out: /'
    exit 0
fi

# main's tree without private/, built in a throwaway index so the working
# folder and the real index are not touched.
index="$(mktemp)"
trap 'rm -f "$index"' EXIT
GIT_INDEX_FILE="$index" git read-tree "$main_ref"
GIT_INDEX_FILE="$index" git rm -r -q --cached --ignore-unmatch -- "$private_dir"
tree="$(GIT_INDEX_FILE="$index" git write-tree)"

if git ls-tree -r --name-only "$tree" | grep -q "^$private_dir/"; then
    echo "private files are still in the snapshot; refusing" >&2
    exit 1
fi

# The upstream commit main is built on.
base="$(git merge-base "$main_ref" "$upstream_ref")"
parents=()
if prev="$(git rev-parse -q --verify refs/heads/public)"; then
    if [ "$(git rev-parse "$prev^{tree}")" = "$tree" ]; then
        echo "public is up to date ($prev)"
        exit 0
    fi
    parents+=(-p "$prev")
    git merge-base --is-ancestor "$base" "$prev" || parents+=(-p "$base")
else
    parents+=(-p "$base")
fi

commit="$(git commit-tree "$tree" "${parents[@]}" \
    -m "Hearth Office: snapshot of $(git rev-parse --short "$main_ref")" \
    -m "Built on upstream $(git rev-parse --short "$base")." )"
git update-ref refs/heads/public "$commit"
echo "public -> $commit"
