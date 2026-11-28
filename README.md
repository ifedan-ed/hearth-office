<!--
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: AGPL
-->

# Hearth Office

Hearth Office is the office suite of Hearth, a self-hosted cloud platform. It
is a fork of [Euro-Office](https://github.com/Euro-Office), which is a fork of
ONLYOFFICE Docs. It edits Word, Excel and PowerPoint files in the browser,
with co-editing, and is hosted by Hearth through WOPI.

This repository is the fork of Euro-Office/DocumentServer. It pins every
component as a submodule and builds the Document Server image.

## Current state

As of 2026-11-27 (the add-ins of that date wait for the next image):

- The fork holds upstream's code at the commits between release v9.3.8 and
  upstream's main of 2026-11-23, with the changes listed under "What the
  fork changes": two fixes to the WOPI page and one to theme loading,
  one to the server's view-mode warning, two to add-in fields in sdkjs,
  Hearth's add-ins (AI Tools, Citations, Thesaurus, Spelling and grammar,
  Speech input), and a plugin SDK served by the server itself.
- GitHub Actions builds all of it: the core (1 h 19 min for the native code,
  8 minutes for the WebAssembly modules), sdkjs, web-apps, the server and
  the image, published as `ghcr.io/ifedan-ed/hearth-office:<tag>`.
- The image is tested through WOPI with a small test host and generated
  test documents: open, edit, save, co-editing with two browsers, versions
  kept by the host, conversion to PDF; a colour theme named by the host; a
  plugin that adds a toolbar tab and a side panel and inserts text at the
  cursor; the AI add-in answering through the server's own proxy.

## The add-ins

Plugins in plain JavaScript that Hearth owns, in hearth-office-plugins under
`sdkjs-plugins/content`, built into the image (`hearth/plugins.txt` names
which).

Built:

- AI Tools (`hearth-ai`): an AI Tools tab and side panel in the
  document, spreadsheet and presentation editors: a chat beside the
  document, and quick actions (summarise, rewrite, simplify, expand,
  proofread, translate, suggest a title, key points, contents, draft,
  explain a formula, notes to slides), with a model picker. Every answer
  is shown first and goes into the document only when accepted, in a
  text document as a tracked change. Its requests go to the host page
  (option `hearthOrigin`), which answers through its own model proxy; the
  browser holds no key. Only the tab loads with the document; the rest on
  the first click.
- Thesaurus (`hearth-thesaurus`): synonyms from the Collaboration tab and
  the right-click menu, from the OpenOffice and LibreOffice thesauruses
  in the image (`hearth/thesaurus.txt` lists the data packs; English
  first). Offline.
- Spelling and grammar (`hearth-proofing`): a Collaboration tab button and
  a side panel listing what the host's LanguageTool server finds, each
  fix put in at its place; asked through the host page.
- Speech input (`hearth-speech`): a Home tab button; the host page records
  and recognises, the add-in types the words at the cursor.
- `hearth-shared`: not a plugin, the message line to the host page, the
  theme helper and the panels' base styles the add-ins share.
- References (`hearth-references`): a References tab in the document
  editor that cites from the host's reference library and PubMed, keeps
  the bibliography in the document's citation style (Edit citation,
  Bibliography, Refresh, Style, Citations), and stores every citation in
  Zotero's own Word field format (`ADDIN ZOTERO_ITEM CSL_CITATION`,
  `ADDIN ZOTERO_BIBL`, the `ZOTERO_PREF_n` document properties), so a
  paper stays live for co-authors who use Zotero. Searching and formatting
  are the host's: the add-in posts its requests to the host page at the
  origin given as the plugin option `hearthOrigin`, and shows no tab
  without it.

Upstream's, shipped: the Zotero tab (changes.md, change 8) and the Photo
Editor (crop, rotate and adjust a picture in the document, in the browser;
its usage report to Google Analytics switched off). None of
upstream's other plugins is in the image.

Planned:

- Hearth's name and mark on the editor's loading screen and About box.

## For a WOPI host

Three things differ from upstream:

- Theme. A host can make a colour theme of its own the default: put the
  theme's JSON file in the themes folder
  (`web-apps/apps/common/main/resources/themes`) and send its id as
  `editorConfig.customization.uiTheme` in the `docs_api_config` form field.
  Upstream's page discarded that value, and the editor did not load such a
  theme's colours at start. A theme a person picks in View, Interface theme
  is remembered by their browser and comes first. The address parameters
  `thm=1` and `thm=2` still pick the stock light and dark themes.
- Loading. `App_LoadingStatus` is posted twice: with `Status: "Frame_Ready"`
  when the editor's shell is up, and with `Status: "Document_Loaded"` and
  `DocumentLoadedTime` when the document is drawn. Upstream posted
  `Document_Loaded` at the first moment.
- Preparing the editor. A host can frame
  `/web-apps/apps/api/documents/hearth-prime.html?kinds=word,cell,slide&ui=main&lang=en&host=<its origin>`
  hidden (`ui=mobile` for the phone editor), before anyone opens a
  document. The page lets the editor's service worker fetch the editor for
  those kinds, pauses while the tab is hidden, and posts
  `{"hearthPrime":"done","version":...,"cached":n,"fetched":n,"failed":n}`
  (as a JSON string) to `host` when it is finished. Deciding whether to
  prime at all (the person's connection, data saver) is the host's job.

## Repositories

| Repository | Upstream | What it is |
| --- | --- | --- |
| hearth-office | DocumentServer | This one: the submodule pins and the image build |
| hearth-office-core | core | C++: the file converter, fonts, rendering, WebAssembly modules |
| hearth-office-core-fonts | core-fonts | Fonts shipped with the server |
| hearth-office-sdkjs | sdkjs | The editors' engine in JavaScript |
| hearth-office-sdkjs-forms | sdkjs-forms | Fillable forms |
| hearth-office-web-apps | web-apps | The editors' interface |
| hearth-office-server | server | Co-editing, conversion and WOPI services |
| hearth-office-dictionaries | dictionaries | Spelling dictionaries |
| hearth-office-document-templates | document-templates | Blank files for "new document" |
| hearth-office-document-formats | document-formats | The list of file types |
| hearth-office-document-server-package | document-server-package | Packaging scripts |
| hearth-office-document-server-integration | document-server-integration | The example host used in tests |
| hearth-office-plugins | plugins | The plugin collection and the plugin SDK; Hearth's add-ins |

Hearth's work is on the `hearth` branch of each repository. Upstream's
history is kept whole underneath it.

## Building

Nothing is compiled by hand. Two workflows do the work:

1. `Hearth core` in hearth-office-core compiles the C++ core and its
   WebAssembly modules and publishes the output as
   `ghcr.io/<owner>/hearth-office-core:<tree>` and
   `ghcr.io/<owner>/hearth-office-core-wasm:<tree>`, where `<tree>` is the git
   tree of the core sources. A tree that is published is not built again. A
   first build can outlast the six hours a hosted runner allows; the compiler
   cache is saved when it does, and running the workflow again finishes it.
2. `Hearth Office image` here builds sdkjs, web-apps, the server, the example
   host and the Document Server image with upstream's own bake file
   (`build/docker-bake.hcl`, target `standalone`), takes the core output from
   step 1, adds Hearth's layer (`hearth/docker-bake.hcl`, target `hearth`)
   and pushes `ghcr.io/<owner>/hearth-office:<tag>`.

The layer (`hearth/Dockerfile`) puts the plugins named in
`hearth/plugins.txt` and the plugin SDK into the server's `sdkjs-plugins`
folder. `hearth/install-plugins.sh` does the copying and points every plugin
page at the SDK the server itself serves (`sdkjs-plugins/v1`) instead of
https://onlyoffice.github.io, where upstream's pages load it from; it stops
the build if a page would still load a script or stylesheet from another
site. To ship another plugin, add its folder name to `hearth/plugins.txt`.

sdkjs, web-apps and server each have a `Hearth build` workflow that checks
the repository still builds inside the image.

## Running

    docker run -d -p 127.0.0.1:8080:80 \
      -e JWT_SECRET=<a long secret> -e WOPI_ENABLED=true \
      ghcr.io/<owner>/hearth-office:latest
    curl -sf http://127.0.0.1:8080/healthcheck

The settings are upstream's; see `build/README.md`.

## What the fork changes

Every difference from upstream, so each can be carried across merges, or
dropped if upstream changes the same thing. Nothing is sent upstream: the
fixes are kept in this fork.

| Where | Change | Why |
| --- | --- | --- |
| hearth-office: `.gitmodules` | Submodule addresses are relative (`../hearth-office-NAME.git`) | Build from the forks |
| hearth-office: `AGENTS.md` | Hearth's rules above upstream's text | Working rules for the fork |
| hearth-office: `hearth/` (new folder) | The public-copy script; the image layer that installs plugins (`Dockerfile`, `docker-bake.hcl`, `install-plugins.sh`, `plugins.txt`) | Hearth's own additions; upstream's image ships no plugins |
| hearth-office: `.github/workflows/hearth-image.yml` (new file) | The image workflow | Builds on hosted runners |
| hearth-office: `.gitmodules`, `.dockerignore` | The plugins repository is a submodule at `plugins`, left out of the main build context | The image layer needs it pinned like every other component |
| core: `.github/workflows/hearth-core.yml` (new file) | Builds and publishes core | Builds on hosted runners |
| sdkjs, web-apps, server: `.github/workflows/hearth-build.yml` (new file) | Build check | The same |
| web-apps: `apps/api/wopi/editor-wopi.ejs` | The host's `customization.uiTheme` is kept; `thm=1`/`thm=2` are applied after the merge and only when present | A host could not make its own theme the default: the page overwrote it with undefined. A plain bug in upstream's page |
| web-apps: `apps/common/main/lib/controller/Themes.js` | A theme from `themes.json` that the editor starts with is applied in full | It was given its name but not its colours, which were written only when it was picked from the menu |
| web-apps: the same file | `App_LoadingStatus` says `Frame_Ready` at onAppReady and `Document_Loaded` at onDocumentReady | `Document_Loaded` was sent when the shell was up, seconds before the document was drawn |
| web-apps: `apps/common/mobile/utils/keysAfterModals.js` (new file), the document, spreadsheet and presentation editors' `mobile/src/controller/Main.jsx` | The phone editors turn key events back on when the last sheet, popover, popup or dialog closes | They were turned off when one opened and never on again: after the formatting sheet, the caret came back but every key was dropped |
| server: `DocService/sources/wopiClient.js` | The "opened in view mode" warning is raised only when the edit action was asked for and refused (the file's rights, or a lock), not when the host opens a file through the view action | Every reader of a read-only share or link was shown a warning about something the host had chosen |
| hearth-office: `hearth/prime/` (new folder), `hearth/Dockerfile` | `hearth-prime.html` and its script, installed beside `api.js`: a host frames the page hidden, and the editor's own service worker fetches the editor's code and base fonts for the kinds named, plus what this browser used under the previous version | The first open of a document downloaded the whole editor (about 23 MB) before showing it; primed, it is as fast as a later open |
| hearth-office: `hearth/precompress.sh`, `hearth/hearth-nginx.conf`, `hearth/Dockerfile` | Brotli copies (quality 11) of the static files, served by nginx's `brotli_static` (Ubuntu's module for the image's nginx) | The editor's scripts and font engine a third smaller than compressed on the fly |
| hearth-office: `hearth/cache-tag.sh`, `hearth/Dockerfile` (edits the installed `documentserver-flush-cache.sh`) | The tag in the editor's versioned addresses is a hash of what is served (the image's static files, the generated font list, the themes), not of the minute the engine started | Every restart moved every address, so every browser's cached editor was thrown away |
| hearth-office: `hearth/cacheable-api-js.sh`, `hearth/hearth-api-js.conf` (new files), `hearth/Dockerfile` (edit the installed `editor-wopi.ejs` and `ds-docservice.conf`) | The WOPI page loads `api.js` without the file in its query, nginx writes the current tag into its address, and `api.js` under the current tag is cached for a year (immutable); under any other tag it is refused, and the unversioned address stays no-store | Every open fetched `api.js` again (no-store, and a different address per file): one round trip on a later open |
| hearth-office: `hearth/Dockerfile` (edits the installed `nginx.conf`) | `worker_rlimit_nofile 65536` and `NGINX_WORKER_CONNECTIONS=8192` | 768 connections per worker refused editors past about 380 |
| hearth-office: `hearth/install-plugins.sh` | An add-in without translations gets `translations/langs.json` with `[]` | The plugin SDK asked for two missing files per add-in on every open |
| hearth-office: `hearth/fonts/caladea` (new folder), `hearth/Dockerfile` | The image's Caladea is replaced by the current release (fonts-crosextra-caladea 20200211, SIL OFL 1.1) | Upstream's core-fonts has Caladea's 2015 release, 5.6 % wider than the current one and than Cambria it stands in for: headings in Cambria laid out to fit in PowerPoint and LibreOffice ran out of their boxes here |
| plugins: `sdkjs-plugins/content/hearth-ai` (new folder) | AI Tools | The add-in above |
| plugins: `sdkjs-plugins/content/photoeditor/index.html`, `scripts/hearth-no-usage-report.js` (new file) | The TOAST UI libraries' usage report switched off globally | Its colour picker reported each use to Google Analytics |
| plugins: `sdkjs-plugins/content/hearth-thesaurus`, `hearth-proofing`, `hearth-speech`, `hearth-shared` (new folders) | Thesaurus, Spelling and grammar, Speech input, their shared scripts | The add-ins above |
| hearth-office: `hearth/thesaurus.txt` (new file), `hearth/Dockerfile`, `hearth/docker-bake.hcl` | The Thesaurus' data packs built in the image from the dictionaries repository | Offline synonyms |
| plugins: `sdkjs-plugins/content/hearth-references` (new folder) | References | The add-in above |
| sdkjs: `word/Editor/Paragraph/ComplexFields/AddinData.js`, `word/Editor/Document.js`, `word/api_plugins.js` | An add-in field's result can be given as formatted paragraphs (`AddinFieldData.Paragraphs`: runs with bold, italic, underline, small capitals, superscript; paragraph indents), read by `AddAddinField` and `UpdateAddinFields`; a plain update keeps the result's text properties | An update dropped a citation's superscript and italics, and a bibliography of several paragraphs pasted into a field lost the field's end mark |
| sdkjs: `word/Editor/Document.js`, `word/Editor/Paragraph/ComplexField.js` | A field's instruction is written in runs of at most 255 characters, also after it is changed | As Word writes it: a citation's instruction holds its whole JSON, often several KB, in one run otherwise |
| sdkjs: `common/text_input2.js` | The editors' hidden text input is 16px on iOS Safari | Safari zooms the page when a field under 16px takes focus; an editor in a host's frame is under the host's viewport, which keeps pinch zoom, so the page zoomed as typing began |

No plugin page of upstream's is edited: the SDK address is rewritten on the
copies that go into the image. core carries no source change; sdkjs and
server carry the ones above.

## Licence

AGPL-3.0, as upstream. Upstream's copyright, licence and attribution notices
are kept as they are; see LICENSE and ATTRIBUTION.

# Upstream's README (Euro-Office)

[![License](https://img.shields.io/badge/License-GNU%20AGPL%20V3-green.svg?style=flat)](https://www.gnu.org/licenses/agpl-3.0.en.html)

# Euro-Office
**Your sovereign office**

[Learn more.](https://github.com/Euro-Office/)

## Install

The Document Server is not a standalone application and needs a platform such as Nextcloud that stores the files.

* **Nextcloud Office**: signed builds for production use, with APT and DNF package repositories, available on [nextcloud-releases/Office-DocumentServer](https://github.com/nextcloud-releases/Office-DocumentServer/releases)
* **Euro-Office**: community builds for testing and contributing, available as deb/rpm on the [releases](https://github.com/Euro-Office/DocumentServer/releases/latest) page and as the `ghcr.io/euro-office/documentserver` container image

See the [installation guide](https://euro-office.github.io/documentation/installation/) in the [official documentation](https://euro-office.github.io/documentation/) for step-by-step instructions.

## Get involved
Get involved! You can file issues, propose pull requests and more. We are looking forward to make the digital sovereign office space better than ever before!

### Try out
We currently provide a docker image for testing and integration purposes. Check the [releases](https://github.com/Euro-Office/DocumentServer/releases) for deb/rpm packages.

```
docker pull ghcr.io/euro-office/documentserver:latest
docker run -i -t -d -p 8080:80 --restart=always -e EXAMPLE_ENABLED=true -e JWT_SECRET=my_long_jwt_secret_at_least_32_chars ghcr.io/euro-office/documentserver:latest
```

### Building

Our build steps and processes are documented in https://github.com/Euro-Office/DocumentServer/tree/main/build. For development there are more detailed steps to build and run individual components in https://github.com/Euro-Office/DocumentServer/tree/main/develop 
