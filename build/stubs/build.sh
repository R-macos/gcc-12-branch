#!/bin/sh

infix=apple-darwin20.0

for arch in arm64 x86_64; do
    carch=$arch
    if [ $arch == arm64 ]; then
	carch=aarch64
    fi
    for prog in ar as dsymutil ld lipo nm objdump otool	ranlib; do
	dst=${carch}-${infix}-${prog}
	echo $dst
	clang -arch arm64 -arch x86_64 -o $dst -DPROG=\"$prog\" -DARCH=\"$arch\" -DAS_IS -O3 driver.c
    done
done
