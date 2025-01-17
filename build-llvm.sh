# Script to build LLVM for iOS Device
# Assumptions:
#  * Run at this repo root
#  * ninja was extracted at this repo root
#  * LLVM is checked out inside this repo
#  * libffi is either built or downloaded in relative location libffi/Release-*

PLATFORM=$1
REPO_DIR=`pwd`
LLVM_DIR=$REPO_DIR/llvm-project
LLVM_INSTALL_DIR=$REPO_DIR/LLVM-$PLATFORM
LIBFFI_DIR=$REPO_DIR/libffi/Release-$PLATFORM

# https://opensource.com/article/18/5/you-dont-know-bash-intro-bash-arrays
CMAKE_ARGS=(-G "Ninja" \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
  -DLLVM_BUILD_TOOLS=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_THREADS=OFF \
  -DLLVM_ENABLE_UNWIND_TABLES=OFF \
  -DLLVM_ENABLE_EH=OFF \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_FFI=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$LLVM_INSTALL_DIR \
  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
  -DCMAKE_MAKE_PROGRAM=$REPO_DIR/ninja)

case $PLATFORM in
  "iphoneos")
	echo "Build LLVM for iOS device"
    ARCH="arm64"
    CMAKE_ARGS+=("-DLLVM_TARGET_ARCH='$ARCH'");;
  "iphonesimulator")
    echo "Build LLVM for iOS simulator"
    ARCH="x86_64"
    # Use xcodebuild -showsdks to find out the available SDK name
    SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
    CMAKE_ARGS+=("-DCMAKE_OSX_SYSROOT=$SYSROOT");;
  "maccatalyst")
    echo "Build LLVM for MacOS"
    ARCH="x86_64"
    # Use xcodebuild -showsdks to find out the available SDK name
    SYSROOT=`xcodebuild -version -sdk macosx Path`
    CMAKE_ARGS+=("-DCMAKE_OSX_SYSROOT=$SYSROOT");; # "-DCMAKE_C_FLAGS=-target x86_64-apple-ios14.1-macabi" "-DCMAKE_CXX_FLAGS=-target x86_64-apple-ios14.1-macabi");;
  *)
    echo "Unknown or missing platform!"
    ARCH=x86_64
	exit 1;;
esac

CMAKE_ARGS+=("-DFFI_INCLUDE_DIR=$LIBFFI_DIR/include/ffi" "-DFFI_LIBRARY_DIR=$LIBFFI_DIR" "-DCMAKE_OSX_ARCHITECTURES='$ARCH'")

echo "Running CMake with " ${#CMAKE_ARGS[@]} "arguments"
for i in ${!CMAKE_ARGS[@]}; do
    echo ${CMAKE_ARGS[$i]}
done

cd llvm-project

rm -rf build
mkdir build
cd build

# Generate configuration for building for iOS Target (on MacOS Host)
# Note: AArch64 = arm64
# Note: We have to use include/ffi subdir for libffi as the main header ffi.h
# includes <ffi_arm64.h> and not <ffi/ffi_arm64.h>. So if we only use
# $DOWNLOADS/libffi/Release-iphoneos/include for FFI_INCLUDE_DIR
# the platform-specific header would not be found! ;lld;libcxx;libcxxabi
case $PLATFORM in
  "iphoneos"|"iphonesimulator")
	    cmake ${CMAKE_ARGS[@]} ../llvm;;
  "maccatalyst")
        cmake ${CMAKE_ARGS[@]} -DCMAKE_C_FLAGS="-target x86_64-apple-ios14.1-macabi" -DCMAKE_CXX_FLAGS="-target x86_64-apple-ios14.1-macabi" ../llvm;;
esac

# When building for real iOS device, we need to open `build_ios/CMakeCache.txt` at this point, search for and FORCIBLY change the value of **HAVE_FFI_CALL** to **1**.
# For some reason, CMake did not manage to determine that `ffi_call` was available even though it really is the case.
# Without this, the execution engine is not built with libffi at all.
sed -i.bak 's/^HAVE_FFI_CALL:INTERNAL=/HAVE_FFI_CALL:INTERNAL=1/g' CMakeCache.txt

# Build
cmake --build .

# Install libs
cmake --install .
