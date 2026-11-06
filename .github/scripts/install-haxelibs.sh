#!/usr/bin/env bash
# Installs exact lib.haxe.org releases into a project-local haxelib repository.
set -euo pipefail

haxelib newrepo
haxelib install hxcpp 4.3.2 --always --quiet
haxelib install utest 1.13.2 --always --quiet
haxelib install StageWebView 1.0.1 --always --quiet
haxelib list
