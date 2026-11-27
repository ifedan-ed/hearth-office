# SPDX-FileCopyrightText: 2026 Hearth contributors
# SPDX-License-Identifier: AGPL-3.0-only
#
# Hearth's addition to upstream's build/docker-bake.hcl: one target, "hearth",
# that puts Hearth's plugins on top of the standalone image (hearth/Dockerfile).
# Used together with upstream's file, from the build folder:
#
#   docker buildx bake -f docker-bake.hcl -f ../hearth/docker-bake.hcl hearth
#
# Paths are relative to the build folder, like upstream's.

target "hearth" {
  context    = "../hearth"
  dockerfile = "Dockerfile"
  contexts = {
    base    = "target:standalone"
    plugins = "../plugins/sdkjs-plugins"
    # The OpenOffice/LibreOffice thesauruses the Thesaurus add-in's data
    # packs are built from (hearth/thesaurus.txt).
    dictionaries = "../dictionaries"
  }
}
