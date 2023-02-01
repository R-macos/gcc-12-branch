#!/bin/sh

set -e

build=apple-darwin20
export MACOSX_DEPLOYMENT_TARGET=11.0

if [ ! -d deps ]; then
    mkdir deps
fi

if [ ! -d deps/src ]; then
    mkdir deps/src
fi

GMP=gmp-6.2.1
MPFR=mpfr-4.2.0
MPC=mpc-1.3.1
ISL=isl-0.24

modules="$GMP $MPFR $MPC $ISL"

## download and unpack sources
cd deps/src
for module in $modules; do
    bm=$(echo $module | sed 's:-.*::')
    suff=.xz
    if [ $bm == mpc ]; then suff=.gz; fi
    if [ $bm == isl ]; then suff=.bz2; fi
    if [ ! -e ${module}.tar$suff ]; then
	if [ $bm == isl ]; then 
	    curl -LO https://gcc.gnu.org/pub/gcc/infrastructure/${module}.tar$suff
	else
	    curl -LO https://ftp.gnu.org/gnu/${bm}/${module}.tar$suff
	fi
    fi
    if [ ! -e ${module} ]; then
	tar fxj ${module}.tar$suff
    fi
done
cd ../..

if [ -z "$UPDATE" ]; then
    rm -rf deps/build
    mkdir deps/build
fi

cd deps
prefix=$(pwd)
relprefix=$(echo $prefix | sed 's:^/*::')
cd build

for module in $modules; do
    bm=$(echo $module | sed 's:-.*::')
    for arch in arm64 x86_64; do
	conf="--prefix=$prefix --disable-shared --enable-static"
	if [ $bm == gmp -a $arch == x86_64 ]; then
	    conf="--build=westmere-$build $conf"
	else
	    carch=$arch
	    if [ $arch == arm64 ]; then
		carch=aarch64
	    fi
	    conf="--build=$carch-$build $conf"
	fi
	if [ -z "$UPDATE" -o ! -e "dst-$arch-$module" ]; then
	    obj=obj-$arch-$module
	    rm -rf $obj
	    mkdir $obj
	    cd $obj
	    ../../src/$module/configure $conf "CC=clang -arch $arch" "CXX=clang++ -arch $arch" CPPFLAGS=-I$prefix/include LIBS=-L$prefix/lib --disable-shared --enable-static --with-pic
	    make -j16
	    rm -rf ../dst-$arch-$module
	    make install DESTDIR="$(pwd)/../dst-$arch-$module"
	    if [ $arch == arm64 ]; then
		make install
	    fi
	    cd ..
	fi
	if [ $arch == x86_64  ]; then
	    cd dst-$arch-$module
	    libs=$(find $relprefix -name \*.a)
	    cd ..
	    for lib in $libs; do
		echo lipo -create -arch arm64 dst-arm64-$module/$lib -arch x86_64 dst-x86_64-$module/$lib -output /$lib
		lipo -create -arch arm64 dst-arm64-$module/$lib -arch x86_64 dst-x86_64-$module/$lib -output /$lib
	    done
	fi
    done
done
