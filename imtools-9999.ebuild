# Copyright 2024 4cecoder
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Fast image manipulation CLI tool written in Zig"
HOMEPAGE="https://github.com/4cecoder/imtools"

SRC_URI=""
KEYWORDS="~amd64 ~x86"

LICENSE="MIT"
SLOT="0"

BDEPEND="dev-lang/zig"

# No runtime dependencies - pure Zig

src_unpack() {
	mkdir -p "${S}" || die
	cp -r "/opt/bytecats/wallpapers/wallpapers/imtools"/{build.zig,src,README.md} "${S}/" || die
}

src_compile() {
	zig build -Doptimize=ReleaseSafe || die "zig build failed"
}

src_install() {
	dobin zig-out/bin/imtools
	dodoc README.md
}
