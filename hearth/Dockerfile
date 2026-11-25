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
#   plugins   the sdkjs-plugins folder of the plugins repository
# The default context is this folder (the list and the install script).

# The Zotero plugin's pages load dist/ built from its src/ by vite. It is
# built here, in the image build on GitHub, never on a server; the stage
# holds only the built files the install step copies over the plugin.
FROM node:22.12.0-bookworm-slim AS zotero-dist
COPY --from=plugins content/zotero /plugin
WORKDIR /plugin
RUN npm ci --no-audit --no-fund && npm run build:modern && npm run build:es5

FROM base

ARG DS_ROOT=/var/www/euro-office/documentserver

# The sources are mounted for this one step, not copied, so the layer holds
# only the installed plugins (the plugins repository is several hundred MB).
RUN --mount=type=bind,from=plugins,target=/src/sdkjs-plugins \
    --mount=type=bind,target=/src/hearth \
    --mount=type=bind,from=zotero-dist,source=/plugin/dist,target=/src/built/zotero/dist \
    bash /src/hearth/install-plugins.sh /src/sdkjs-plugins /src/hearth/plugins.txt "$DS_ROOT/sdkjs-plugins" /src/built \
    && chmod -R a+rX "$DS_ROOT/sdkjs-plugins"
