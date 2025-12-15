# Copyright 2024 4cecoder
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="Fast image manipulation CLI tool written in Zig"
HOMEPAGE="https://github.com/4cecoder/imtools"
SRC_URI="https://github.com/4cecoder/imtools/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~arm64"
IUSE="+ffmpeg +curl ollama"

BDEPEND="dev-lang/zig"
RDEPEND="
	ffmpeg? ( media-video/ffmpeg )
	curl? ( net-misc/curl )
	ollama? ( app-misc/ollama )
"

src_compile() {
	zig build -Doptimize=ReleaseSafe || die "zig build failed"
}

src_install() {
	dobin zig-out/bin/imtools
	dodoc README.md LICENSE
	dodoc -r docs
}
