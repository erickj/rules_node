# The node_repository_impl is mostly taken from rules_nodejs :)
#
# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Install NodeJS when the user runs node_repositories() from their WORKSPACE.

We fetch a specific version of Node, to ensure builds are hermetic.
We then create a repository @nodejs which provides the
node binary to other rules.
"""

YARN_BUILD_FILE_CONTENT = """
package(default_visibility = [ "//visibility:public" ])
exports_files([
  "bin/yarn",
  "bin/yarn.js",
])
"""

YARN_LOCKFILE_BUILD_FILE_CONTENT = """
package(default_visibility = [ "//visibility:public" ])
exports_files([
  "index.js",
])
"""

NODE_BUILD_FILE_CONTENT = """
package(default_visibility = ["//visibility:public"])
exports_files([
  "{0}",
  "{1}",
])
alias(name = "node", actual = "{0}")
alias(name = "npm", actual = "{1}")
"""


def _node_repository_impl(repository_ctx):
  version = repository_ctx.attr.node_version
  sha256 = repository_ctx.attr.linux_sha256
  arch = "linux-x64"
  node = "bin/node"
  npm = "bin/npm"
  compression_format = "tar.xz"

  os_name = repository_ctx.os.name.lower()
  if os_name.startswith("mac os"):
    arch = "darwin-x64"
    sha256 = repository_ctx.attr.darwin_sha256
  elif os_name.find("windows") != -1:
    arch = "win-x64"
    node = "node.exe"
    npm = "npm.cmd"
    compression_format = "zip"
    sha256 = repository_ctx.attr.windows_sha256

  prefix = "node-v%s-%s" % (version, arch)
  url = "https://nodejs.org/dist/v{version}/{prefix}.{compression_format}".format(
    version = version,
    prefix = prefix,
    compression_format = compression_format,
  )

  repository_ctx.download_and_extract(
    url = url,
    stripPrefix = prefix,
    sha256 = sha256,
  )

  repository_ctx.file("BUILD.bazel", content = NODE_BUILD_FILE_CONTENT.format(node, npm))


_node_repository = repository_rule(
  _node_repository_impl,
  attrs = {
    "node_version": attr.string(
      default = "8.10.0",
    ),
    "linux_sha256": attr.string(
      default = "92220638d661a43bd0fee2bf478cb283ead6524f231aabccf14c549ebc2bc338",
    ),
    "darwin_sha256": attr.string(
      default = "03eac783c88ac5253942504658b02105b8acce5c07ff702f55c2fc47d7798664",
    ),
    "windows_sha256": attr.string(
      default = "51873acda1ce02d756a6849cbd630789c8f26e3405a7a8135132ade5c09cfa30",
    ),
  },
)


def node_repositories(yarn_version="v1.5.1",
                      yarn_sha256="cd31657232cf48d57fdbff55f38bfa058d2fb4950450bd34af72dac796af4de1",
                      **kwargs):

    native.new_http_archive(
      name = "yarn",
      url = "https://github.com/yarnpkg/yarn/releases/download/{yarn_version}/yarn-{yarn_version}.tar.gz".format(
        yarn_version = yarn_version,
      ),
      sha256 = yarn_sha256,
      strip_prefix="yarn-%s" % yarn_version,
      build_file_content = YARN_BUILD_FILE_CONTENT,
    )

    native.new_http_archive(
      name = "yarnpkg_lockfile",
      url = "https://registry.yarnpkg.com/@yarnpkg/lockfile/-/lockfile-1.0.0.tgz",
      sha256 = "472add7ad141c75811f93dca421e2b7456045504afacec814b0565f092156250",
      strip_prefix="package",
      build_file_content =  YARN_LOCKFILE_BUILD_FILE_CONTENT,
    )

    _node_repository(
      name = "node",
      **kwargs
    )
