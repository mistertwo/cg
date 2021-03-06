# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6
PYTHON_COMPAT=( python3_5 )

inherit cmake-utils eutils python-single-r1 gnome2-utils fdo-mime pax-utils git-r3 versionator toolchain-funcs flag-o-matic

DESCRIPTION="3D Creation/Animation/Publishing System"
HOMEPAGE="http://www.blender.org/"

EGIT_REPO_URI="http://git.blender.org/blender.git"

LICENSE="|| ( GPL-2 BL )"
SLOT="9999"
KEYWORDS=""
IUSE_BUILD="+blender -game-engine +addons contrib +nls -ndof +cycles freestyle -player"
IUSE_COMPILER="openmp +sse sse2"
IUSE_SYSTEM="X -portable -valgrind -debug -doc"
IUSE_IMAGE="-dpx -dds +openexr jpeg2k tiff"
IUSE_CODEC="+openal -sdl jack avi +ffmpeg -sndfile -quicktime"
IUSE_COMPRESSION="-lzma +lzo"
IUSE_MODIFIERS="+fluid +smoke +boolean +remesh oceansim +decimate"
IUSE_LIBS="osl +openvdb +opensubdiv +opencolorio +openimageio collada -alembic opencl"
IUSE_GPU="+opengl -opengl3 +cuda -sm_20 -sm_21 -sm_30 -sm_35 -sm_50"
IUSE="${IUSE_BUILD} ${IUSE_COMPILER} ${IUSE_SYSTEM} ${IUSE_IMAGE} ${IUSE_CODEC} ${IUSE_COMPRESSION} ${IUSE_MODIFIERS} ${IUSE_LIBS} ${IUSE_GPU}"

REQUIRED_USE="${PYTHON_REQUIRED_USE}
            cycles? ( openexr openimageio )
            smoke? ( openvdb )
            contrib? ( addons )"

LANGS="en ar bg ca cs de el es es_ES fa fi fr he hr hu id it ja ky ne nl pl pt pt_BR ru sr sr@latin sv tr uk zh_CN zh_TW"
for X in ${LANGS} ; do
	IUSE+=" linguas_${X}"
	REQUIRED_USE+=" linguas_${X}? ( nls )"
done

RDEPEND="${PYTHON_DEPS}
	dev-vcs/git
	dev-python/numpy[${PYTHON_USEDEP}]
	dev-python/requests[${PYTHON_USEDEP}]
	dev-libs/jemalloc
	sys-libs/zlib
	smoke? ( sci-libs/fftw:3.0 )
	media-libs/freetype
	media-libs/libpng:0=
	sci-libs/ldl
	virtual/libintl
	virtual/jpeg:0=
	dev-libs/boost[nls?,threads(+)]
	sci-libs/colamd
	opengl? ( 
		virtual/opengl
		media-libs/glew:*
		virtual/glu
	)
	X? (
	   x11-libs/libXi
	   x11-libs/libX11
	   x11-libs/libXxf86vm
	)
	opencolorio? ( media-libs/opencolorio )
	cycles? (
		openimageio? ( >=media-libs/openimageio-1.1.5 )
		cuda? ( dev-util/nvidia-cuda-toolkit )
		osl? (
		      >=sys-devel/llvm-3.1
		      media-gfx/osl
		      )
		openvdb? ( media-gfx/openvdb
		dev-cpp/tbb )
	)
	sdl? ( media-libs/libsdl[sound,joystick] )
	tiff? ( media-libs/tiff:0 )
	openexr? ( media-libs/openexr )
	ffmpeg? ( >=media-video/ffmpeg-2.2[x264,xvid,mp3,encode,jpeg2k?] )
	jpeg2k? ( media-libs/openjpeg:0 )
	openal? ( >=media-libs/openal-1.6.372 )
	jack? ( media-sound/jack-audio-connection-kit )
	sndfile? ( media-libs/libsndfile )
	collada? ( media-libs/opencollada )
	ndof? (
		app-misc/spacenavd
		dev-libs/libspnav
	)
	quicktime? ( media-libs/libquicktime )
	valgrind? ( dev-util/valgrind )
	lzma? ( app-arch/lzma )
	lzo? ( dev-libs/lzo )
	alembic? ( media-libs/alembic )
	opensubdiv? ( media-libs/opensubdiv )
	opencl? ( =app-eselect/eselect-opencl-1.1.0-r9 )
	nls? ( virtual/libiconv )"

DEPEND="${RDEPEND}
	dev-cpp/eigen:3
	nls? ( sys-devel/gettext )
	doc? (
		dev-python/sphinx
		app-doc/doxygen[-nodot(-),dot(+)]
	)"

CMAKE_BUILD_TYPE="Release"

PATCHES=( "${FILESDIR}"/01-${PN}-2.68-doxyfile.patch
        "${FILESDIR}"/06-${PN}-2.68-fix-install-rules.patch )

blender_check_requirements() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp

	if use doc; then
		CHECKREQS_DISK_BUILD="4G" check-reqs_pkg_pretend
	fi
}

pkg_pretend() {
	blender_check_requirements
}

pkg_setup() {
	blender_check_requirements
	python-single-r1_pkg_setup
}

src_prepare() {
	#add custom matcap
	rm ${S}/release/datafiles/matcaps/mc10.jpg
	cp ${FILESDIR}/mc10.jpg ${S}/release/datafiles/matcaps/

	# remove some bundled deps
	rm -r \
		extern/libopenjpeg \
		extern/glew \
		extern/glew-es \
		extern/Eigen3 \
		|| die

	default

	# we don't want static glew, but it's scattered across
	# multiple files that differ from version to version
	# !!!CHECK THIS SED ON EVERY VERSION BUMP!!!
	local file
	while IFS="" read -d $'\0' -r file ; do
		sed -i -e '/-DGLEW_STATIC/d' "${file}" || die
	done < <(find . -type f -name "CMakeLists.txt")

	# Disable MS Windows help generation. The variable doesn't do what it
	# it sounds like.
	sed -e "s|GENERATE_HTMLHELP      = YES|GENERATE_HTMLHELP      = NO|" \
	    -i doc/doxygen/Doxyfile || die
	
	ewarn "$(echo "Remaining bundled dependencies:";
			( find extern -mindepth 1 -maxdepth 1 -type d; ) | sed 's|^|- |')"
	# linguas cleanup
	local i
	if ! use nls; then
		rm -r "${S}"/release/datafiles/locale || die
	else
		if [[ -n "${LINGUAS+x}" ]] ; then
			cd "${S}"/release/datafiles/locale/po
			for i in *.po ; do
				mylang=${i%.po}
				has ${mylang} ${LINGUAS} || { rm -r ${i} || die ; }
			done
		fi
	fi
}

src_configure() {
	append-flags -funsigned-char -fno-strict-aliasing -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -DWITH_OPENNL -DHAVE_STDBOOL_H
	#append-lfs-flags
	local mycmakeargs=""
	#CUDA Kernal Selection
	local CUDA_ARCH=""
	if use cuda; then
        if use sm_20; then
			if [[ -n "${CUDA_ARCH}" ]] ; then
				CUDA_ARCH="${CUDA_ARCH};sm_20"
			else
				CUDA_ARCH="sm_20"
			fi
		fi
		if use sm_21; then
			if [[ -n "${CUDA_ARCH}" ]] ; then
				CUDA_ARCH="${CUDA_ARCH};sm_21"
			else
				CUDA_ARCH="sm_21"
			fi
		fi
		if use sm_30; then
			if [[ -n "${CUDA_ARCH}" ]] ; then
				CUDA_ARCH="${CUDA_ARCH};sm_30"
			else
				CUDA_ARCH="sm_30"
			fi
		fi
		if use sm_35; then
			if [[ -n "${CUDA_ARCH}" ]] ; then
				CUDA_ARCH="${CUDA_ARCH};sm_35"
			else
				CUDA_ARCH="sm_35"
			fi
		fi
		if use sm_50; then
			if [[ -n "${CUDA_ARCH}" ]] ; then
				CUDA_ARCH="${CUDA_ARCH};sm_50"
			else
				CUDA_ARCH="sm_50"
			fi
		fi

		#If a kernel isn't selected then all of them are built by default
		if [ -n "${CUDA_ARCH}" ] ; then
			mycmakeargs+=(
				
				-DCYCLES_CUDA_BINARIES_ARCH=${CUDA_ARCH}
			)
		fi
		mycmakeargs+=(
			-DWITH_CYCLES_CUDA=ON
			-DWITH_CYCLES_CUDA_BINARIES=ON
			-DCUDA_INCLUDES=/opt/cuda/include
			-DCUDA_LIBRARIES=/opt/cuda/lib64
			-DCUDA_NVCC=/opt/cuda/bin/nvcc
		)
	fi

	mycmakeargs+=(
		-DCMAKE_INSTALL_PREFIX=/usr
		-DPYTHON_VERSION=${EPYTHON/python/}
		-DPYTHON_LIBRARY=$(python_get_library_path)
		-DPYTHON_INCLUDE_DIR=$(python_get_includedir)
		-DWITH_BLENDER=$(usex blender)
		-DWITH_BOOST=ON
		-DWITH_BUILDINFO=ON
		-DWITH_CODEC_AVI=$(usex avi)
		-DWITH_CODEC_FFMPEG=$(usex ffmpeg)
		-DWITH_CODEC_SNDFILE=$(usex sndfile)
		-DWITH_ALEMBIC=$(usex alembic)
		-DWITH_QUICKTIME=$(usex quicktime)
		-DWITH_FFTW3=$(usex smoke)
		-DWITH_CPU_SSE=$(usex sse)
		-DWITH_RAYOPTIMIZATION=$(usex sse)
		-DWITH_CYCLES=$(usex cycles)
		-DWITH_CYCLES_NATIVE_ONLY=$(usex cycles)
		-DWITH_FREESTYLE=$(usex freestyle)
		-DWITH_GAMEENGINE=$(usex game-engine)
		-DWITH_HEADLESS=$(usex !X)
		-DWITH_X11=$(usex X)
		-DWITH_GHOST_XDND=$(usex X)
		-DWITH_INTERNATIONAL=$(usex nls)
		-DWITH_LLVM=$(usex osl)
		-DWITH_CYCLES_OSL=$(usex osl)
        -DLLVM_STATIC=OFF
		-DLLVM_LIBRARY=/usr/lib
		-DWITH_LZMA=$(usex lzma)
		-DWITH_LZO=$(usex lzo)
		-DWITH_VALGRIND=$(usex valgrind)
		-DWITH_MOD_BOOLEAN=$(usex boolean)
		-DWITH_MOD_REMESH=$(usex remesh)
		-DWITH_MOD_FLUID=$(usex fluid)
		-DWITH_MOD_OCEANSIM=$(usex oceansim)
		-DWITH_MOD_DECIMATE=$(usex decimate)
		-DWITH_MOD_SMOKE=$(usex smoke)
		-DWITH_OPENCOLLADA=$(usex collada)
		-DWITH_OPENCOLORIO=$(usex opencolorio)
		-DWITH_OPENIMAGEIO=$(usex openimageio)
		-DWITH_OPENMP=$(usex openmp)
		-DWITH_OPENSUBDIV=$(usex opensubdiv)
		-DWITH_OPENVDB=$(usex openvdb)
		-DWITH_OPENVDB_BLOSC=$(usex openvdb)
		-DWITH_PLAYER=$(usex player)
		-DWITH_IMAGE_CINEON=$(usex dpx)
		-DWITH_IMAGE_DDS=$(usex dds)
		-DWITH_IMAGE_OPENEXR=$(usex openexr)
		-DWITH_IMAGE_OPENJPEG=$(usex jpeg2k)
		-DWITH_IMAGE_TIFF=$(usex tiff)
		-DWITH_INPUT_NDOF=$(usex ndof)
		-DWITH_OPENAL=$(usex openal)
		-DWITH_SDL=$(usex sdl)
		-DWITH_JACK=$(usex jack)
		-DWITH_SYSTEM_EIGEN3=$(usex !portable)
		-DWITH_SYSTEM_LZO=$(usex !portable)
		-DWITH_SYSTEM_OPENJPEG=$(usex !portable)
		-DWITH_SYSTEM_GLEW=$(usex !portable)
		-DWITH_SYSTEM_GLES=$(usex !portable)
		-DWITH_INSTALL_PORTABLE=$(usex portable)
		-DWITH_STATIC_LIBS=$(usex portable)
		-DWITH_PYTHON_INSTALL=$(usex portable)
		-DWITH_PYTHON_INSTALL_NUMPY=$(usex portable)
		-DWITH_PYTHON_INSTALL_REQUESTS=$(usex portable)
		-DWITH_GL_PROFILE_COMPAT=$(usex opengl) 
		-DWITH_GL_PROFILE_CORE=$(usex opengl3)
		-DWITH_OPENCL=$(usex opencl)
		-DWITH_CYCLES_DEVICE_OPENCL=$(usex opencl)
		-DWITH_DEBUG=$(usex debug)
		-DWITH_GPU_DEBUG=$(usex debug)
		-DWITH_WITH_CYCLES_DEBUG=$(usex debug)
		-DWITH_DOCS=$(usex doc)
		-DWITH_DOC_MANPAGE=$(usex doc)
		-DWITH_OPENNL=ON
		-DWITH_C11=ON
		-DWITH_CXX11=ON
	)

	cmake-utils_src_configure
}

src_compile() {
	cmake-utils_src_compile

	if use doc; then
		einfo "Generating Blender C/C++ API docs ..."
		cd "${CMAKE_USE_DIR}"/doc/doxygen || die
		doxygen -u Doxyfile
		doxygen || die "doxygen failed to build API docs."

		cd "${CMAKE_USE_DIR}" || die
		einfo "Generating (BPY) Blender Python API docs ..."
		"${BUILD_DIR}"/bin/blender --background --python doc/python_api/sphinx_doc_gen.py -noaudio || die "blender failed."

		cd "${CMAKE_USE_DIR}"/doc/python_api || die
		sphinx-build sphinx-in BPY_API || die "sphinx failed."
	fi
}

src_test() { :; }

src_install() {
	local i

	# Pax mark blender for hardened support.
	pax-mark m "${CMAKE_BUILD_DIR}"/bin/blender

	if use doc; then
		docinto "API/python"
		dohtml -r "${CMAKE_USE_DIR}"/doc/python_api/BPY_API/*

		docinto "API/blender"
		dohtml -r "${CMAKE_USE_DIR}"/doc/doxygen/html/*
	fi

	# fucked up cmake will relink binary for no reason
	emake -C "${CMAKE_BUILD_DIR}" DESTDIR="${D}" install/fast

	python_fix_shebang "${ED%/}"/usr/bin/blender-thumbnailer.py
	python_optimize "${ED%/}"/usr/share/blender/${PV}/scripts
}

pkg_preinst() {
	gnome2_icon_savelist
}

pkg_postinst() {
	elog
	elog "Blender compiles from master thunk by default"
	elog "You may change a branch and a rev, for ex, in /etc/portage/env/blender"
	elog "EGIT_COMMIT="v2.77a""
	elog "EGIT_BRANCH="master""
	elog "and don't forget add to /etc/portage/package.env"
	elog "media-gfx/blender blender"
	elog
	elog "It is recommended to change your blender temp directory"
	elog "from /tmp to /home/user/tmp or another tmp file under your"
	elog "home directory. This can be done by starting blender, then"
	elog "dragging the main menu down do display all paths."
	elog
	gnome2_icon_cache_update
	fdo-mime_desktop_database_update
}

pkg_postrm() {
	gnome2_icon_cache_update
	fdo-mime_desktop_database_update
}
