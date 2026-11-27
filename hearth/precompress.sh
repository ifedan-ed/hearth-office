#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Hearth contributors
# SPDX-License-Identifier: AGPL-3.0-only
#
# precompress.sh DS_ROOT
#
# Writes a brotli copy (name.br, quality 11) beside each static file the
# editor loads, for nginx's brotli_static (hearth-nginx.conf): the editor's
# scripts and font engine arrive about a third smaller than Caddy's zstd
# or gzip made them on the fly (sdk-all.js 3.6 MB to 2.4 MB), and no
# processor time is spent compressing them per request. A browser that
# does not take brotli gets the plain file, which the proxy in front
# compresses as before. No gzip copies: every browser the editor supports
# takes brotli.
#
# Left out, because the engine's start writes them again and a copy made
# here would go stale: api.js (and its template), AllFonts.js, the font
# and theme pictures in sdkjs/common/Images, the presentation themes, the
# x2t caches (*.cache) and the interface themes (a host mounts its own).
# Files under 1 KB are left out too: brotli saves nothing worth a lookup.
set -euo pipefail
cd "$1"
find sdkjs web-apps sdkjs-plugins dictionaries -type f -size +1k \
  \( -name '*.js' -o -name '*.css' -o -name '*.json' -o -name '*.html' -o -name '*.wasm' \
     -o -name '*.svg' -o -name '*.dic' -o -name '*.aff' -o -name '*.txt' -o -name '*.xml' \) \
  ! -path 'web-apps/apps/api/documents/api.js*' \
  ! -path 'sdkjs/common/AllFonts.js' \
  ! -path 'sdkjs/common/Images/*' \
  ! -path 'sdkjs/slide/themes/*' \
  ! -path 'web-apps/apps/common/main/resources/themes/*' \
  ! -name '*.cache' -print0 \
  | xargs -0 -r -P "$(nproc)" -n 32 brotli -q 11 -k -f
# The copies are served by nginx (www-data) like the files themselves.
find sdkjs web-apps sdkjs-plugins dictionaries -name '*.br' -exec chmod a+r {} +
