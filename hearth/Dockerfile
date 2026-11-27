# SPDX-FileCopyrightText: 2026 Hearth contributors
# SPDX-License-Identifier: AGPL-3.0-only
#
# The Hearth Office image: upstream's standalone Document Server image, as
# this repository builds it, with Hearth's plugins and the plugin SDK put in.
# Upstream's image ships no plugins at all, and upstream's Dockerfiles are
# left untouched; this is one layer on top.
#
# Build contexts (hearth/docker-bake.hcl names them):
#   base      the standalone image (bake target "standalone")
#   plugins       the sdkjs-plugins folder of the plugins repository
#   dictionaries  the dictionaries repository (the thesauruses)
# The default context is this folder (the lists, the install script, and
# the files for serving the editor faster: prime/, cache-tag.sh,
# precompress.sh, hearth-nginx.conf).

# The Zotero plugin's pages load dist/ built from its src/ by vite. It is
# built here, in the image build on GitHub, never on a server; the stage
# holds only the built files the install step copies over the plugin.
FROM node:22.12.0-bookworm-slim AS zotero-dist
COPY --from=plugins content/zotero /plugin
WORKDIR /plugin
RUN npm ci --no-audit --no-fund && npm run build:modern && npm run build:es5

# The Thesaurus add-in's data packs, built from the thesauruses in the
# dictionaries repository (MyThes .dat files) by the add-in's own script:
# one small file per prefix, so a lookup fetches a few kilobytes from the
# Document Server and nothing from anywhere else. Which packs: thesaurus.txt.
FROM node:22.12.0-bookworm-slim AS thesaurus-data
COPY --from=plugins content/hearth-thesaurus/.dev/build-data.mjs /build/build-data.mjs
COPY thesaurus.txt /build/thesaurus.txt
RUN --mount=type=bind,from=dictionaries,target=/dictionaries \
    node /build/build-data.mjs /out/hearth-thesaurus/data --list /build/thesaurus.txt /dictionaries

FROM base

ARG DS_ROOT=/var/www/euro-office/documentserver

# The sources are mounted for this one step, not copied, so the layer holds
# only the installed plugins (the plugins repository is several hundred MB).
RUN --mount=type=bind,from=plugins,target=/src/sdkjs-plugins \
    --mount=type=bind,target=/src/hearth \
    --mount=type=bind,from=zotero-dist,source=/plugin/dist,target=/src/built/zotero/dist \
    --mount=type=bind,from=thesaurus-data,source=/out/hearth-thesaurus,target=/src/built/hearth-thesaurus \
    bash /src/hearth/install-plugins.sh /src/sdkjs-plugins /src/hearth/plugins.txt "$DS_ROOT/sdkjs-plugins" /src/built \
    && chmod -R a+rX "$DS_ROOT/sdkjs-plugins"

# Serving the editor faster (Hearth's docs/office-speed-capacity.md):
#
# - nginx's brotli_static module (Ubuntu's package for the image's own
#   nginx) and brotli copies of the static files, made once here
#   (precompress.sh), served by hearth-nginx.conf;
# - the editor prepared in the background: hearth-prime.html and its
#   script beside api.js, a page a host frames hidden so the editor's own
#   service worker fetches the editor before the first open (prime/);
# - a cache tag that changes only when what is served changes
#   (cache-tag.sh, which documentserver-flush-cache.sh asks instead of
#   hashing the minute of the start), so a restart keeps every browser's
#   cache of the editor;
# - nginx's connection ceiling: 768 per worker was about 380 editors (each
#   holds two connections); 8192 per worker, with the file limit to match.
#   The worker count is the host's setting (NGINX_WORKER_PROCESSES, read by
#   the entrypoint), one per processor it gives the engine.
COPY prime/hearth-prime.html prime/hearth-prime.js $DS_ROOT/web-apps/apps/api/documents/
COPY cache-tag.sh /usr/local/bin/hearth-cache-tag
COPY hearth-nginx.conf /etc/nginx/conf.d/hearth-nginx.conf
RUN --mount=type=bind,target=/src/hearth \
    set -eu \
    && apt-get update \
    && apt-get install -y --no-install-recommends brotli libnginx-mod-http-brotli-static \
    && rm -rf /var/lib/apt/lists/* \
    && chmod a+r $DS_ROOT/web-apps/apps/api/documents/hearth-prime.* \
    && bash /src/hearth/precompress.sh "$DS_ROOT" \
    && (cd "$DS_ROOT" && find sdkjs web-apps sdkjs-plugins dictionaries -type f ! -name '*.br' -print0 | sort -z | xargs -0 md5sum | md5sum | cut -c1-32 > hearth-static.md5) \
    && flush=/usr/bin/documentserver-flush-cache.sh \
    && grep -q '^HASH=${HASH:-$(date' "$flush" \
    && sed -i 's|^HASH=${HASH:-$(date.*$|HASH=${HASH:-$(hearth-cache-tag)}|' "$flush" \
    && grep -q '^HASH=${HASH:-$(hearth-cache-tag)}$' "$flush" \
    && hearth-cache-tag | grep -qE '^[0-9a-f]{32}$' \
    && grep -q '^worker_processes' /etc/nginx/nginx.conf \
    && sed -i 's/^worker_processes.*/&\nworker_rlimit_nofile 65536;/' /etc/nginx/nginx.conf \
    && nginx -t
ENV NGINX_WORKER_CONNECTIONS=8192

# Caladea, Cambria's metric twin, at the version LibreOffice and Hearth's
# presentations measure in (fonts-crosextra-caladea 20200211, SIL OFL
# 1.1, its licence beside it). Upstream's core-fonts carries the 2015
# release, whose letters are 5.6 % wider: a Cambria heading Hearth sized to
# its box wrapped onto one more line here and ran out of it. The engine
# makes its font lists from core-fonts when it starts, so replacing the
# files is all it takes.
COPY fonts/caladea/ /tmp/caladea/
RUN rm -f "$DS_ROOT"/core-fonts/caladea/*.ttf \
    && install -m 0444 /tmp/caladea/*.ttf /tmp/caladea/OFL.txt /tmp/caladea/COPYRIGHT "$DS_ROOT/core-fonts/caladea/" \
    && rm -rf /tmp/caladea

