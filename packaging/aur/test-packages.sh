#!/usr/bin/env bash

set -euo pipefail

aur_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$aur_root/../.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

test_bin() {
	local bin_srcinfo
	bin_srcinfo="$(cd "$aur_root/kernel-panic-bin" && makepkg --printsrcinfo)"
	if [[ "$bin_srcinfo" == *'${pkgver}'* ]]; then
		printf '%s\n' 'FAIL: kernel-panic-bin publishes literal ${pkgver} source URLs' >&2
		return 1
	fi
	if [[ "$bin_srcinfo" != *'releases/download/v2.4.7/kernel-panic'* ]]; then
		printf '%s\n' 'FAIL: kernel-panic-bin release URL did not resolve pkgver' >&2
		return 1
	fi
}

test_git() {
	local git_src="$scratch/src"
	local git_pkg="$scratch/pkg"
	mkdir -p "$git_src" "$git_pkg" "$scratch/data" "$scratch/config"
	ln -s "$repo_root" "$git_src/kernel-panic"
	cp "$aur_root/kernel-panic-git/kernel-panic.desktop" "$git_src/"
	cp "$aur_root/kernel-panic-git/kernel-panic.sh" "$git_src/"
	cp "$aur_root/kernel-panic-git/LICENSE" "$git_src/"

	(
		cd "$aur_root/kernel-panic-git"
		source ./PKGBUILD
		srcdir="$git_src"
		pkgdir="$git_pkg"
		if ! XDG_DATA_HOME="$scratch/data" XDG_CONFIG_HOME="$scratch/config" \
			build >"$scratch/build.log" 2>&1; then
			cat "$scratch/build.log" >&2
			return 1
		fi
		package
	)

	test -x "$git_pkg/usr/bin/kernel-panic" || {
		printf '%s\n' 'FAIL: kernel-panic-git did not package a launcher' >&2
		return 1
	}
	test -s "$git_pkg/usr/share/kernel-panic/kernel-panic.pck" || {
		printf '%s\n' 'FAIL: kernel-panic-git did not package project data' >&2
		return 1
	}
}

case "${1:-all}" in
	bin) test_bin ;;
	git) test_git ;;
	all) test_bin; test_git ;;
	*) printf 'usage: %s [bin|git|all]\n' "$0" >&2; exit 2 ;;
esac

printf '%s\n' 'AUR_PACKAGE_TESTS_PASS'
