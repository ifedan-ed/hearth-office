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

As of 2026-11-24:

- The fork holds upstream's code unchanged, at the commits between release
  v9.3.8 and upstream's main of 2026-11-23, plus the build workflows below.
  No source file of any component is changed yet.
- The first builds on GitHub Actions are running. Until one has finished
  and been tested, the image to use is upstream's
  `ghcr.io/euro-office/documentserver:v9.3.8`.
- Tested against upstream's image through WOPI: open, edit, save, co-editing
  with two browsers, versions kept by the host, conversion to PDF; a colour
  theme set by a settings file; a plugin that adds a toolbar tab and a side
  panel and inserts text at the cursor; the AI plugin answering through the
  server's own proxy.

## The add-ins

Planned, not built. Both are plugins in plain JavaScript that Hearth owns:

- References: a reference manager in its own toolbar tab, with a PubMed
  search, citations stored as Word fields so the file stays a normal .docx,
  and bibliographies in CSL styles.
- Dictate: voice typing. Words are inserted at the cursor as they are
  recognised; the audio goes to the Hearth server, never to the browser's
  built-in recogniser.

Also planned: Hearth's colours and name in the editor, and two small fixes
to the WOPI page (keep the host's colour theme; report "document loaded"
when the document is drawn).

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
   host and the final image with upstream's own bake file
   (`build/docker-bake.hcl`, target `standalone`), takes the core output from
   step 1, and pushes `ghcr.io/<owner>/hearth-office:<tag>`.

sdkjs, web-apps and server each have a `Hearth build` workflow that checks
the repository still builds inside the image.

## Running

    docker run -d -p 127.0.0.1:8080:80 \
      -e JWT_SECRET=<a long secret> -e WOPI_ENABLED=true \
      ghcr.io/<owner>/hearth-office:latest
    curl -sf http://127.0.0.1:8080/healthcheck

The settings are upstream's; see `build/README.md`.

## What the fork changes

Every difference from upstream, so each can be carried across merges or
dropped.

| Where | Change | Why |
| --- | --- | --- |
| hearth-office: `.gitmodules` | Submodule addresses are relative (`../hearth-office-NAME.git`) | Build from the forks |
| hearth-office: `AGENTS.md` | Hearth's rules above upstream's text | Working rules for the fork |
| hearth-office: `HEARTH.md`, `hearth/`, `.github/workflows/hearth-image.yml` (new files) | This page, the public-copy script, the image workflow | Hearth's own additions |
| core: `.github/workflows/hearth-core.yml` (new file) | Builds and publishes core | Builds on hosted runners |
| sdkjs, web-apps, server: `.github/workflows/hearth-build.yml` (new file) | Build check | The same |

No source file of any component is changed yet.

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
