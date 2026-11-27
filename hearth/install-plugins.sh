#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Hearth contributors
# SPDX-License-Identifier: AGPL-3.0-only
#
# install-plugins.sh SOURCE LIST DEST [BUILT]
#
# Copies the plugin SDK and the plugins named in LIST from a checkout of the
# plugins repository (SOURCE is its sdkjs-plugins folder) into the Document
# Server's plugin folder DEST, ready to be served.
#
# Upstream's plugin pages load the plugin SDK (plugins.js, plugins-ui.js,
# plugins.css) from https://onlyoffice.github.io. A Hearth Office server
# loads nothing from outside sites, so every copied page is pointed at the
# SDK copy served beside the plugins instead (DEST/v1), by a relative address
# that fits the page's depth. This is done here, on the copies, so no plugin
# file in the repository has to be edited to be shipped.
#
# BUILT, when given, holds files built in the image build for a plugin
# (BUILT/<name>/...): they are copied over that plugin's own (the Zotero
# plugin's dist/, built from its src/).
#
# A listed folder with a .shared file instead of config.json is not a
# plugin but scripts and styles the plugins load from ../NAME/ (Hearth's
# add-ins share hearth-shared): copied the same way, never listed by the
# server as a plugin.
#
# The script fails if a copied page still loads a script or a stylesheet
# from another site: a plugin that needs one is not fit to ship as it is.
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "usage: install-plugins.sh SOURCE LIST DEST [BUILT]" >&2
    exit 2
fi
source_dir="$1"; list="$2"; dest="$3"; built_dir="${4:-}"
outside_sdk='https://onlyoffice.github.io/sdkjs-plugins/v1/'

# The SDK: the three files pages load, and its third-party notices.
mkdir -p "$dest/v1"
for file in plugins.js plugins-ui.js plugins.css 3rd-Party.txt; do
    cp "$source_dir/v1/$file" "$dest/v1/$file"
done

# Names from the list: blank lines and # comments are skipped.
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$list" | while read -r name; do
    from="$source_dir/content/$name"
    if [ ! -f "$from/config.json" ] && [ ! -f "$from/.shared" ]; then
        echo "plugin $name: neither $from/config.json nor $from/.shared found" >&2
        exit 1
    fi
    rm -rf "${dest:?}/$name"
    mkdir -p "$dest/$name"
    # Dot-folders hold a plugin's own build sources (.dev) and are not served.
    (cd "$from" && find . -mindepth 1 -maxdepth 1 ! -name '.*' -exec cp -R {} "$dest/$name/" \;)
    # Files built in the image build replace the plugin's own copies.
    if [ -n "$built_dir" ] && [ -d "$built_dir/$name" ]; then
        cp -R "$built_dir/$name/." "$dest/$name/"
    fi

    # Point each page at the local SDK: "../v1/" from the plugin's top
    # folder, one more "../" for every folder below it.
    find "$dest/$name" -type f -name '*.html' | while read -r page; do
        grep -q "$outside_sdk" "$page" || continue
        inner="${page#"$dest/$name/"}"
        depth="$(printf '%s' "$inner" | tr -cd '/' | wc -c)"
        up='../'
        for _ in $(seq "$depth"); do up="../$up"; done
        sed -i "s#${outside_sdk}#${up}v1/#g" "$page"
    done

    # A plugin with no translations says so: the plugin SDK
    # (sdkjs/common/plugins/plugin_base.js) asks for translations/langs.json
    # in any language but English, and on a 404 asks for that language's
    # file too, so each such add-in cost two failed requests on every open.
    # An empty list is the SDK's own "none" (it then translates nothing).
    if [ ! -e "$dest/$name/translations" ]; then
        mkdir -p "$dest/$name/translations"
        printf '[]\n' > "$dest/$name/translations/langs.json"
    fi

    # Anything a page would still fetch from another site.
    if grep -rnE --include='*.html' '<(script|link)[^>]+(src|href)="(https?:)?//' "$dest/$name"; then
        echo "plugin $name: the pages above load from an outside site" >&2
        exit 1
    fi
    echo "installed $name"
done
