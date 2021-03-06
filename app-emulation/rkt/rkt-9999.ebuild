# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

AUTOTOOLS_AUTORECONF=yes
AUTOTOOLS_IN_SOURCE_BUILD=yes

inherit autotools-utils flag-o-matic systemd toolchain-funcs
inherit cros-workon

CROS_WORKON_PROJECT="coreos/rkt"
CROS_WORKON_LOCALNAME="rkt"
CROS_WORKON_REPO="git://github.com"


if [[ "${PV}" == "9999" ]]; then
	KEYWORDS="~amd64"
else
	KEYWORDS="amd64"
	CROS_WORKON_COMMIT="a4b17f07700afd4e24be0153ca4fc73c35e14c31" # v0.8.1
fi

PXE_VERSION="794.1.0"
PXE_SYSTEMD_VERSION="222"
PXE_URI="http://alpha.release.core-os.net/amd64-usr/${PXE_VERSION}/coreos_production_pxe_image.cpio.gz"
PXE_FILE="${PN}-pxe-${PXE_VERSION}.img"

SRC_URI="rkt_stage1_coreos? ( $PXE_URI -> $PXE_FILE )"

DESCRIPTION="A CLI for running app containers, and an implementation of the App
Container Spec."
HOMEPAGE="https://github.com/coreos/rkt"

LICENSE="Apache-2.0"
SLOT="0"
IUSE="doc examples +rkt_stage1_coreos rkt_stage1_host rkt_stage1_src +actool"
REQUIRED_USE="^^ ( rkt_stage1_coreos rkt_stage1_host rkt_stage1_src )"

DEPEND=">=dev-lang/go-1.4.1
	app-arch/cpio
	sys-fs/squashfs-tools
	dev-perl/Capture-Tiny
	rkt_stage1_src? (
		>=sys-apps/systemd-222
		app-shells/bash
	)"
RDEPEND="!app-emulation/rocket
	actool? ( !app-emulation/actool )
	rkt_stage1_host? (
		~sys-apps/systemd-222
		app-shells/bash
	)"

BUILDDIR="build-${P}"

src_configure() {
	local myeconfargs=(
		--with-stage1-image-path="/usr/share/rkt/stage1.aci"
	)

	if use rkt_stage1_host; then
		myeconfargs+=( --with-stage1="host" )
	elif use rkt_stage1_src; then
		myeconfargs+=( --with-stage1="src" )
	elif use rkt_stage1_coreos; then
		myeconfargs+=( --with-stage1="coreos" )
		myeconfargs+=( --with-coreos-local-pxe-image-path="${DISTDIR}/${PXE_FILE}" )
		myeconfargs+=( --with-coreos-local-pxe-image-systemd-version=v"${PXE_SYSTEMD_VERSION}" )
	fi

	# Go's 6l linker does not support PIE, disable so cgo binaries
	# which use 6l+gcc for linking can be built correctly.
	if gcc-specs-pie; then
		append-ldflags -nopie
	fi

	export CC=$(tc-getCC)
	export CGO_ENABLED=1
	export CGO_CFLAGS="${CFLAGS}"
	export CGO_CPPFLAGS="${CPPFLAGS}"
	export CGO_CXXFLAGS="${CXXFLAGS}"
	export CGO_LDFLAGS="${LDFLAGS}"
	export BUILDDIR

	autotools-utils_src_configure
}

src_install() {
	dodoc README.md
	use doc && dodoc -r Documentation
	use examples && dodoc -r examples
	use actool && dobin "${S}/${BUILDDIR}/bin/actool"

	dobin "${S}/${BUILDDIR}/bin/rkt"

	insinto /usr/share/rkt/
	doins "${S}/${BUILDDIR}/bin/stage1.aci"

	systemd_dounit "${S}"/dist/init/systemd/${PN}-gc.service
	systemd_dounit "${S}"/dist/init/systemd/${PN}-gc.timer
	systemd_enable_service multi-user.target ${PN}-gc.timer
	systemd_dounit "${S}"/dist/init/systemd/${PN}-metadata.service
	systemd_dounit "${S}"/dist/init/systemd/${PN}-metadata.socket
	systemd_enable_service sockets.target ${PN}-metadata.socket
}
