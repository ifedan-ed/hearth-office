#!/bin/sh
# SPDX-FileCopyrightText: 2026 Hearth contributors
# SPDX-License-Identifier: AGPL-3.0-only
#
# hearth-cache-tag: prints the tag in the editor's versioned addresses
# (/<product version>-<tag>/web-apps/...), which documentserver-flush-cache.sh
# writes into nginx's ds-cache.conf and api.js at every start.
#
# Upstream's tag is the md5 of the minute the engine started, so every
# restart of the container (a settings change, a server reboot) moved
# every address, and every browser's service worker cache of the editor
# (web-apps, sdkjs, fonts, add-ins: 20 MB and more) was thrown away. This
# tag changes only when what is served changes:
#   - hearth-static.md5, written by the image build from every file in
#     sdkjs, web-apps, sdkjs-plugins and dictionaries (a new image);
#   - AllFonts.js and the font files' names and sizes, which the start
#     generates from the fonts installed (fonts added or removed);
#   - the themes folder, which a host may mount over the image's.
# The flush script is the one caller; HASH given to it still wins.
set -eu
ds=/var/www/euro-office/documentserver
{
  cat "$ds/hearth-static.md5"
  md5sum "$ds/sdkjs/common/AllFonts.js"
  find "$ds/fonts" -maxdepth 1 -type f -printf '%f %s\n' | sort
  find "$ds/web-apps/apps/common/main/resources/themes" -type f -print0 | sort -z | xargs -0 -r md5sum
} | md5sum | cut -c1-32
