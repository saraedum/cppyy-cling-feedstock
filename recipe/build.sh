#!/bin/bash

# Much of this file (and the entire recipe in fact) has been taken from the
# root-feedstock.

export VERBOSE=1
# Build a C++17 aware Cling
export STDCXX=17
# Do not perform auto-detection of CPU features
export EXTRA_CLING_ARGS=-O2

# Manually set the deployment_target
# May not be very important but nice to do
OLDVERSIONMACOS='${MACOSX_VERSION}'
sed -i -e "s@${OLDVERSIONMACOS}@${MACOSX_DEPLOYMENT_TARGET}@g" src/cmake/modules/SetUpMacOS.cmake

declare -a CMAKE_PLATFORM_FLAGS
if [ "$(uname)" == "Linux" ]; then
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_AR=${GCC_AR}")
    CMAKE_PLATFORM_FLAGS+=("-DCLANG_DEFAULT_LINKER=${LD_GOLD}")
    CMAKE_PLATFORM_FLAGS+=("-DDEFAULT_SYSROOT=${PREFIX}/${HOST}/sysroot")
    CMAKE_PLATFORM_FLAGS+=("-DRT_LIBRARY=${PREFIX}/${HOST}/sysroot/usr/lib/librt.so")

    # Hide symbols from LLVM/clang to avoid conflicts with other libraries
    for lib_name in $(ls $PREFIX/lib | grep -E 'lib(LLVM|clang).*\.a'); do
        export CXXFLAGS="${CXXFLAGS} -Wl,--exclude-libs,${lib_name}"
    done
    echo "CXXFLAGS is now '${CXXFLAGS}'"
else
    CMAKE_PLATFORM_FLAGS+=("-Dcocoa=ON")
    CMAKE_PLATFORM_FLAGS+=("-DCLANG_RESOURCE_DIR_VERSION='5.0.0'")

    # Print out and possibly fix SDKROOT (Might help Azure)
    echo "SDKROOT is: '${SDKROOT}'"
    echo "CONDA_BUILD_SYSROOT is: '${CONDA_BUILD_SYSROOT}'"
    export SDKROOT="${CONDA_BUILD_SYSROOT}"
fi

# Remove -std=c++XX from build ${CXXFLAGS}
CXXFLAGS=$(echo "${CXXFLAGS}" | sed -E 's@-std=c\+\+[^ ]+@@g')
export CXXFLAGS

# The cross-linux toolchain breaks find_file relative to the current file
# Patch up with sed
sed -i -E 's#(ROOT_TEST_DRIVER RootTestDriver.cmake PATHS \$\{THISDIR\} \$\{CMAKE_MODULE_PATH\} NO_DEFAULT_PATH)#\1 CMAKE_FIND_ROOT_PATH_BOTH#g' \
    src/cmake/modules/RootNewMacros.cmake

export CMAKE_CLING_ARGS=${CMAKE_PLATFORM_FLAGS[@]}

# Some flags that root-feedstock sets. They probably don't hurt when building cppyy…
export CMAKE_CLING_ARGS="${CMAKE_CLING_ARGS} -DCMAKE_INSTALL_RPATH=\"${SP_DIR}/cppyy_backend/lib\" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON -DCMAKE_SKIP_BUILD_RPATH=OFF -DCLING_BUILD_PLUGINS=OFF -DPYTHON_EXECUTABLE=\"${PYTHON}\" -DTBB_ROOT_DIR=\"${PREFIX}\" -DCMAKE_INSTALL_PREFIX=\"${PREFIX}\" -Dexplicitlink=ON -Dexceptions=ON -Dfail-on-missing=ON -Dgnuinstall=OFF -Dshared=ON -Dsoversion=ON -Dbuiltin-glew=OFF -Dbuiltin_xrootd=OFF -Dbuiltin_davix=OFF -Dbuiltin_afterimage=OFF -Drpath=ON -DCMAKE_CXX_STANDARD=17 -Dcastor=off -Dgfal=OFF -Dmysql=OFF -Doracle=OFF -Dpgsql=OFF -Dpythia6=OFF -Droottest=OFF"
# Variables that cppyy's setup.py usually sets, we might not actually want all of this 
export CMAKE_CLING_ARGS="${CMAKE_CLING_ARGS} -DCMAKE_CXX_STANDARD=${STDCXX} -DLLVM_ENABLE_TERMINFO=0 -Dminimal=ON -Dasimage=OFF -Droot7=OFF -Dhttp=OFF -Dbuiltin_pcre=ON -Dbuiltin_freetype=OFF -Dbuiltin_zlib=ON -Dbuiltin_xxhash=ON"
# Use conda-forge's clang & llvm
export CMAKE_CLING_ARGS="${CMAKE_CLING_ARGS} -Dbuiltin_llvm=OFF -Dbuiltin_clang=OFF"

mkdir build
cd build
cmake $CMAKE_CLING_ARGS ../src
cmake --build . --target install --config Release
rm "${SP_DIR}/cppyy_backend/etc/allDict.cxx.pch"
