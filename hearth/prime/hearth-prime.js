// SPDX-FileCopyrightText: 2026 Hearth contributors
// SPDX-License-Identifier: AGPL-3.0-only
//
// Prepares the editor in the background: fills the editor's own service
// worker cache (sdkjs/common/serviceworker/document_editor_service_worker.js)
// with what an open will ask for, so that a person's first open of a
// document costs what a later open does. The page is
// /<version>/web-apps/apps/api/documents/hearth-prime.html: an unversioned
// address is sent there by nginx's "script caching protection" rule, so the
// host never needs to know the version, and the page sits inside the
// worker's scope (/<version>/).
//
// Everything goes through the worker: the page registers it as the editor
// does, waits until the worker controls the page, and then fetches. The
// worker answers from its cache or from the network and keeps what it
// fetched, under the same rules as for the editor (versioned files only,
// its storage checks). Nothing is written to the cache from here, so the
// cache stays exactly what the editor itself would have made.
//
// What is fetched, for the kinds the host names (?kinds=word,cell,slide)
// and the interface (?ui=main for a computer, mobile for a phone):
//   - what this browser's editor fetched under the version before this
//     one, read from that version's cache before the new worker deletes it
//     (so after an engine update, exactly what this person used: their
//     fonts, the phone editor's chunks, the add-ins);
//   - the core list below: each kind's scripts, the font engine, the
//     interface's scripts and styles, and the fonts a default document of
//     that kind draws with (by name, through AllFonts.js, since the font
//     files are numbered when the engine starts).
// Files already in the cache are not fetched again, so a page that finds
// everything there costs one look into the cache.
//
// The page holds back while the host's tab is hidden, fetches three files
// at a time, and tells the host when it is done: a message
// {"hearthPrime":"done", version, cached, fetched, failed} to the origin
// in ?host=. The host decides whether to prime at all (connection, data
// saver, its own switch); this page does not second-guess it.
'use strict';

(function () {
  // The editor's folder in web-apps for each kind (sdkjs's folder name).
  var apps = { word: 'documenteditor', cell: 'spreadsheeteditor', slide: 'presentationeditor' };

  var query = new URLSearchParams(location.search);
  var page = 'web-apps/apps/api/documents/hearth-prime.html';
  var root = location.pathname.slice(0, location.pathname.length - page.length); // "/9.3.9-<tag>/"
  var version = root.split('/').filter(Boolean).pop() || '';
  var cachePrefix = 'document_editor_static_';
  var host = originOf(query.get('host'));
  var kinds = (query.get('kinds') || '').split(',').filter(function (k) { return k in apps; });
  var ui = query.get('ui') === 'mobile' ? 'mobile' : 'main';
  var lang = (query.get('lang') || 'en').split('-')[0].toLowerCase().replace(/[^a-z]/g, '') || 'en';

  // Fonts a default document draws with, by kind (measured on Word,
  // spreadsheet and presentation files made from python's default
  // templates: their Calibri and Cambria are drawn as Carlito and Caladea,
  // Arial, Times New Roman and Courier New as Liberation, and a Word
  // theme's Japanese font names as NanumBarunGothic).
  var fonts = {
    word: ['Liberation Sans', 'Liberation Serif', 'Liberation Mono', 'Carlito', 'Caladea', 'OpenSymbol', 'Open Sans', 'NanumBarunGothic'],
    cell: ['Liberation Sans', 'Carlito', 'Caladea', 'Open Sans'],
    slide: ['Liberation Sans', 'Liberation Serif', 'Liberation Mono', 'Carlito', 'Caladea', 'OpenSymbol', 'Open Sans', 'DejaVu Sans'],
  };

  function originOf(s) {
    try {
      var u = new URL(s || '');
      return u.protocol === 'https:' || u.protocol === 'http:' ? u.origin : '';
    } catch (e) {
      return '';
    }
  }

  function tell(what, extra) {
    if (!host || parent === window) return;
    var m = { hearthPrime: what, version: version };
    for (var k in extra) m[k] = extra[k];
    parent.postMessage(JSON.stringify(m), host);
  }

  // core lists the files of the core list, relative to the version root.
  function core() {
    var out = [
      'sdkjs/common/AllFonts.js',
      'sdkjs/common/libfont/engine/fonts.js',
      'sdkjs/common/libfont/engine/fonts.wasm',
      'sdkjs/common/Charts/ChartStyles.js',
      // The spelling checker the editor starts as it opens (its own
      // engine; the dictionaries load by language later).
      'sdkjs/common/spell/spell/spell.js',
      'sdkjs/common/spell/spell/spell.wasm',
      'sdkjs/common/Images/cursors/svg.json',
      'web-apps/vendor/jquery/jquery.min.js',
      'web-apps/vendor/socketio/socket.io.min.js',
      'web-apps/vendor/xregexp/xregexp-all-min.js',
      'sdkjs-plugins/v1/plugins.js',
      'sdkjs-plugins/v1/plugins-ui.js',
    ];
    // The font list's pictures, at the screen's pixel ratio as the editor
    // picks them (the 1x file, or @1.25x to @2x).
    var r = window.devicePixelRatio || 1;
    out.push('sdkjs/common/Images/fonts_thumbnail' + (r < 1.125 ? '' : r < 1.375 ? '@1.25x' : r < 1.625 ? '@1.5x' : r < 1.875 ? '@1.75x' : '@2x') + '.png.bin');
    if (ui === 'main') {
      out.push('sdkjs/common/device_scale.js?__inline=true', 'web-apps/vendor/requirejs/require.js',
        'web-apps/apps/common/main/resources/alphabetletters/alphabetletters.json',
        'web-apps/apps/common/main/resources/alphabetletters/qwertyletters.json');
    }
    kinds.forEach(function (k) {
      var app = 'web-apps/apps/' + apps[k] + '/' + ui + '/';
      out.push('sdkjs/' + k + '/sdk-all-min.js', 'sdkjs/' + k + '/sdk-all.js', app + 'locale/' + lang + '.json');
      if (ui === 'main') out.push(app + 'app.js', app + 'app.css', app + 'code.js');
      else out.push(app + 'dist/js/app.js', app + 'css/framework7.css');
      if (k === 'cell') out.push(ui === 'main' ? 'sdkjs/cell/css/main.css' : 'sdkjs/cell/css/main-mobile.css', 'web-apps/vendor/underscore/underscore-min.js');
      if (k === 'word' && ui === 'main') {
        out.push(app + 'resources/numbering/numbering-lists.json', app + 'resources/numbering/multilevel-lists.json');
      }
    });
    return out;
  }

  // fontFiles names the font files of the kinds' fonts, from AllFonts.js
  // (window.__fonts_infos: name, then file index and face for regular,
  // italic, bold and bold italic; window.__fonts_files: the file names).
  function fontFiles() {
    var infos = window.__fonts_infos || [], files = window.__fonts_files || [];
    var want = {};
    kinds.forEach(function (k) { fonts[k].forEach(function (n) { want[n] = true; }); });
    var out = [];
    infos.forEach(function (info) {
      if (!want[info[0]]) return;
      for (var i = 1; i < info.length; i += 2) {
        if (info[i] >= 0 && files[info[i]] && out.indexOf('fonts/' + files[info[i]]) < 0) out.push('fonts/' + files[info[i]]);
      }
    });
    return out;
  }

  // mobileAssets reads the phone editors' pages for their styles and
  // scripts, whose names carry a build hash.
  async function mobileAssets() {
    var out = [];
    for (var i = 0; i < kinds.length; i++) {
      var dir = 'web-apps/apps/' + apps[kinds[i]] + '/mobile/';
      var res = await fetch(root + dir + 'index.html');
      if (!res.ok) continue;
      var doc = new DOMParser().parseFromString(await res.text(), 'text/html');
      doc.querySelectorAll('script[src], link[rel="stylesheet"][href]').forEach(function (el) {
        var u = new URL(el.getAttribute('src') || el.getAttribute('href'), location.origin + root + dir);
        if (u.origin === location.origin && u.pathname.indexOf(root) === 0) out.push(u.pathname.slice(root.length) + u.search);
      });
    }
    return out;
  }

  // previous reads the addresses the editor fetched under older versions
  // (their caches are deleted when this version's worker takes over),
  // moved to this version's root. Each older cache is read once and
  // forgotten here; the worker deletes it.
  async function previous() {
    var out = [];
    var names = (await caches.keys()).filter(function (n) { return n.indexOf(cachePrefix) === 0 && n !== cachePrefix + version; });
    for (var i = 0; i < names.length; i++) {
      var old = names[i].slice(cachePrefix.length);
      var keys = await (await caches.open(names[i])).keys();
      keys.forEach(function (req) {
        var u = new URL(req.url);
        var at = u.pathname.indexOf('/' + old + '/');
        if (u.origin !== location.origin || at < 0) return;
        out.push(u.pathname.slice(at + old.length + 2) + u.search);
      });
    }
    return out;
  }

  // controlled registers the editor's worker for this version and resolves
  // once it controls this page (its activation claims open pages).
  function controlled() {
    return new Promise(function (resolve, reject) {
      if (navigator.serviceWorker.controller) return resolve();
      var t = setTimeout(function () { reject(new Error('the service worker did not take the page')); }, 20000);
      navigator.serviceWorker.addEventListener('controllerchange', function () { clearTimeout(t); resolve(); }, { once: true });
      navigator.serviceWorker.register(root + 'document_editor_service_worker.js').catch(function (e) { clearTimeout(t); reject(e); });
    });
  }

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src;
      s.onload = resolve;
      s.onerror = function () { reject(new Error('could not load ' + src)); };
      document.head.appendChild(s);
    });
  }

  // visible resolves when the host's tab is shown (at once if it is).
  function visible() {
    if (document.visibilityState === 'visible') return Promise.resolve();
    return new Promise(function (resolve) {
      document.addEventListener('visibilitychange', function on() {
        if (document.visibilityState !== 'visible') return;
        document.removeEventListener('visibilitychange', on);
        resolve();
      });
    });
  }

  // fetchAll asks the worker for each address not yet in the cache, three
  // at a time, pausing while the tab is hidden.
  async function fetchAll(paths) {
    var cache = await caches.open(cachePrefix + version);
    var todo = [];
    for (var i = 0; i < paths.length; i++) {
      if (!(await cache.match(root + paths[i]))) todo.push(paths[i]);
    }
    var fetched = 0, failed = 0, next = 0;
    async function worker() {
      while (next < todo.length) {
        var path = todo[next++];
        await visible();
        try {
          var res = await fetch(root + path, { credentials: 'same-origin' });
          if (res.ok) { await res.arrayBuffer(); fetched++; } else failed++;
        } catch (e) {
          failed++;
        }
      }
    }
    await Promise.all([worker(), worker(), worker()]);
    // The worker stores a response after it has answered; give it a moment
    // and count what is really in the cache.
    var stored = 0;
    for (var tries = 0; tries < 20; tries++) {
      stored = 0;
      for (var j = 0; j < paths.length; j++) if (await cache.match(root + paths[j])) stored++;
      if (stored >= paths.length - failed) break;
      await new Promise(function (r) { setTimeout(r, 250); });
    }
    return { cached: stored, fetched: fetched, failed: failed, wanted: paths.length };
  }

  async function run() {
    if (!version || !kinds.length || !('serviceWorker' in navigator) || !window.caches) {
      tell('skipped', { reason: 'nothing to do here' });
      return;
    }
    await visible();
    var before = await previous();
    await controlled();
    await loadScript(root + 'sdkjs/common/AllFonts.js');
    var list = core().concat(fontFiles(), ui === 'mobile' ? await mobileAssets() : [], before);
    // Converted documents (cache/files) are the worker's other cache and
    // depend on the file; they are never primed.
    var seen = {};
    list = list.filter(function (p) {
      if (seen[p] || p.indexOf('cache/files/') === 0) return false;
      seen[p] = true;
      return true;
    });
    tell('done', await fetchAll(list));
  }

  run().catch(function (e) { tell('failed', { reason: String(e && e.message || e) }); });
})();
