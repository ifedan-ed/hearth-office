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

FROM base

ARG DS_ROOT=/var/www/euro-office/documentserver

# The sources are mounted for this one step, not copied, so the layer holds
# only the installed plugins (the plugins repository is several hundred MB).
RUN --mount=type=bind,from=plugins,target=/src/sdkjs-plugins \
    --mount=type=bind,target=/src/hearth \
    bash /src/hearth/install-plugins.sh /src/sdkjs-plugins /src/hearth/plugins.txt "$DS_ROOT/sdkjs-plugins" \
    && chmod -R a+rX "$DS_ROOT/sdkjs-plugins"
