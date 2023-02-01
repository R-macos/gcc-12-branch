#!/bin/bash

prefix=/opt/gfortran
infix=apple-darwin20.0
export MACOSX_DEPLOYMENT_TARGET=11.0

# ----

set -e

if [ ! -e $prefix/bin ]; then
    echo Creating $prefix
    mkdir -p $prefix/bin
fi

BASE=$(pwd)

echo Build stubs
( cd stubs && sh build.sh )

echo Copy stubs to $prefix
cp -p stubs/*darwin* $prefix/bin

if [ ! -e $prefix/SDK ]; then
    if [ -z "$SDKROOT" ]; then
	if [ -e /Library/Developer/CommandLineTools/SDKs/MacOSX11.sdk ]; then
	    SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX11.sdk
	else
	    SDKROOT=$(xcrun --show-sdk-path)
	fi
    fi
    echo Link SDK to $SDKROOT
    ln -s $SDKROOT $prefix/SDK
    export SDKROOT
else
    export SDKROOT=$prefix/SDK
fi

depprefix=$(pwd)/deps
if [ ! -e ${depprefix}/lib/libmpc.a ]; then
    if [ -e ${prefix}/lib/libmpc.a ]; then
	depprefix="$prefix"
    else
	echo "ERROR: cannot find build dependencies - try running deps.sh first" >&2
	exit 1
    fi
fi

echo "Using $depprefix for build dependencies"

## no-slash version of the prefix (relative)
relprefix=$(echo $prefix | sed 's:^/*::')

fixpaths() {
    for libfile in $(find $relprefix -name \*.dylib -type f); do
	echo " - $libfile"
	install_name_tool -id /$libfile $libfile
	for libname in $(find $relprefix -name \*.dylib -type f | sed 's:.*/::'); do
	    install_name_tool -change "@rpath/$libname" "/$(dirname $libfile)/$libname" "$libfile"
	done
    done
}

## harch, tarch, [lang]
build1 () {
    rm -rf obj-${harch}-${tarch}
    mkdir obj-${harch}-${tarch}
    cd obj-${harch}-${tarch}
    charch=$harch
    ctarch=$tarch
    if [ $harch == arm64 ]; then charch=aarch64; fi
    if [ $tarch == arm64 ]; then ctarch=aarch64; fi
    if [ -z "$lang" ]; then lang=fortran; fi

    if [ $harch == $tarch ]; then ## native => clang
	cc="clang -arch $harch"
	cxx="clang++ -arch $harch"
    else ## cross => use what we built
	cc="${charch}-${infix}-gcc"
	cxx="${charch}-${infix}-g++"
    fi
    PATH=$prefix/bin:$PATH ../gcc-12-branch/configure --host=${charch}-${infix} --build=${charch}-${infix} --target=${ctarch}-${infix} --prefix=$prefix --enable-languages=$lang --with-gmp=$depprefix --with-mpc=$depprefix --with-mpfr=$depprefix --with-isl=$depprefix --with-sysroot=$prefix/SDK --enable-version-specific-runtime-libs LDFLAGS_FOR_TARGET=-Wl,-headerpad_max_install_names "CC=$cc" "CXX=$cxx"

    PATH=$prefix/bin:$PATH make -j32 BOOT_CFLAGS='-O'
    dst="$(pwd)/../dst-${harch}-${tarch}"
    rm -rf "$dst"
    PATH=$prefix/bin:$PATH make install DESTDIR="$dst"

    echo Fixing paths ...
    cd "$dst"
    fixpaths

    echo Copying installed ...
    rsync -a $relprefix/ $prefix/

    cd ..
    echo Done with $harch compiling for $tarch
}

## 1) native
harch=arm64
tarch=arm64
if [ -z "$UPDATE" -o ! -e dst-${harch}-${tarch} ]; then
    lang=c,c++,fortran
    build1
fi

## 2) x86_64 native
harch=x86_64
tarch=x86_64
if [ -z "$UPDATE" -o ! -e dst-${harch}-${tarch} ]; then
    lang=c,c++,fortran
    build1
fi

## 3) arm->x86 cross
harch=arm64
tarch=x86_64
if [ -z "$UPDATE" -o ! -e dst-${harch}-${tarch} ]; then
    lang=fortran
    build1
fi

## 4) x86->arm cross
harch=x86_64
tarch=arm64
if [ -z "$UPDATE" -o ! -e dst-${harch}-${tarch} ]; then
    lang=fortran
    build1
fi
