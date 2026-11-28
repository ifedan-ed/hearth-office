#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Hearth contributors
# SPDX-License-Identifier: AGPL-3.0-only
#
# cacheable-api-js.sh DS_ROOT CONF
#
# Makes the editor's loader, api.js, cacheable on a later open of a
# document through WOPI (Hearth's docs/office-speed-capacity.md); CONF is
# hearth-api-js.conf, which says how. Three edits to installed upstream
# files, each checked before and after, so the build fails when upstream
# moves the lines instead of shipping an image that is quietly different:
#
# 1. The WOPI page (editor-wopi.ejs) loads api.js without the file in the
#    query. The query is a shard key, which only a load balancer in front
#    of several engines reads; Hearth runs one, and with it every document
#    had its own address for the same api.js.
# 2. CONF is installed with the engine's version filled in, taken from
#    the loader's own template, so the page's address and the loader's
#    test for a tag in its address (extendAppPath) agree.
# 3. ds-docservice.conf includes CONF where upstream's one api.js location
#    was, before its catch-all for static files.
set -euo pipefail
ds=$1 conf=$2
# Each check says what moved; a bare "! cmd" would not stop the script.
fail() { echo "cacheable-api-js.sh: $*" >&2; exit 1; }

page=$ds/web-apps/apps/api/wopi/editor-wopi.ejs
old='src="../../../web-apps/apps/api/documents/api.js<%- apiQuery %>"'
new='src="../../../web-apps/apps/api/documents/api.js"'
[ "$(grep -cF "$old" "$page")" = 1 ] || fail "the WOPI page's api.js line moved"
sed -i "s|$(printf '%s' "$old" | sed 's/[.[\*^$|]/\\&/g')|$new|" "$page"
[ "$(grep -cF "$new" "$page")" = 1 ] || fail "the WOPI page was not edited"
if grep -q 'apiQuery' "$page"; then fail "the WOPI page still uses apiQuery"; fi

tpl=$ds/web-apps/apps/api/documents/api.js.tpl
version=$(sed -n "s|^ *const ver = '/\([0-9]*\.[0-9]*\.[0-9]*\)-{{HASH_POSTFIX}}';\$|\1|p" "$tpl")
[ "$(printf '%s\n' "$version" | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+$')" = 1 ] || fail "no version in the loader's template"
mkdir -p /etc/nginx/hearth
sed "s/@VERSION@/$version/g" "$conf" > /etc/nginx/hearth/api-js.conf
if grep -q '@VERSION@' /etc/nginx/hearth/api-js.conf; then fail "the version was not filled in"; fi

# Upstream's block, exactly; anything else there and the build stops.
nginx_ds=/etc/euro-office/documentserver/nginx/includes/ds-docservice.conf
grep -qF "\$the_prefix/$version-\$cache_tag\$cache" "$nginx_ds" || fail "nginx's versioned addresses are not $version"
expected='location ~ ^(\/[\d]+\.[\d]+\.[\d]+[\.|-][\w]+)?\/(web-apps\/apps\/api\/documents\/api\.js)$ {
  expires off;
  add_header Cache-Control "no-store, no-cache, must-revalidate";
  # gzip_static on;
  alias  /var/www/euro-office/documentserver/$2;
}'
start=${expected%%$'\n'*}
[ "$(grep -cxF "$start" "$nginx_ds")" = 1 ] || fail "upstream's api.js location moved"
# awk reads the line from its environment: -v would take its backslashes
# as escapes.
[ "$(S=$start awk '$0==ENVIRON["S"]{on=1} on{print} on&&$0=="}"{exit}' "$nginx_ds")" = "$expected" ] || fail "upstream's api.js location changed"
# Written through the file, not replaced: /etc/nginx/includes links to it.
edited=$(S=$start awk '$0==ENVIRON["S"]{skip=1; print "include /etc/nginx/hearth/api-js.conf;"; next} skip{if($0=="}")skip=0; next} {print}' "$nginx_ds")
printf '%s\n' "$edited" > "$nginx_ds"
[ "$(grep -cxF 'include /etc/nginx/hearth/api-js.conf;' "$nginx_ds")" = 1 ] || fail "the include was not put in"
if grep -qF 'api\/documents\/api\.js)$' "$nginx_ds"; then fail "upstream's api.js location is still there"; fi
