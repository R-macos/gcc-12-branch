#!/bin/bash
#
# experimental driver-driver which supports multiple
# -arch <arch> flags and runs lipo on the results.
#
# NOTE: requires gcc to be compiled with _GCC_WRITE_OUTFILES support.
#

# -- you can customize here --
PROG=gfortran
PREFIX=/opt/gfortran
BUILD=apple-darwin20.0
# --- end --

set -e

i=0
DARGS=("$@")
FINARGS=()
ARCHS=()
TOF=/tmp/outfiles.$$

while [ $i -lt ${#DARGS[@]} ]; do
    if [ ${DARGS[$i]} == -arch ]; then
	i=$((i + 1))
	ARCHS+=(${DARGS[$i]})
    else
	FINARGS+=(${DARGS[$i]})
    fi
    i=$((i + 1))
done

if [ -z $ARCHS ]; then
    ARCHS+=arm64
fi

if [ ${#ARCHS[@]} == 1 ]; then
    dst=$ARCHS
    if [ $dst == arm64 ]; then
	dst=aarch64
    fi
    exec ${PREFIX}/bin/${dst}-${BUILD}-$PROG ${FINARGS[@]}
fi

LIPOS=()
LOUT=()
for arch in ${ARCHS[@]}; do
    echo $arch
    dst=$arch
    if [ $dst == arm64 ]; then
	dst=aarch64
    fi
    rm -f $TOF
    _GCC_WRITE_OUTFILES=$TOF ${PREFIX}/bin/${dst}-${BUILD}-$PROG -arch $arch ${FINARGS[@]}
    i=0
    for fn in `cat $TOF`; do
	echo "Look for $fn"
	if [ -e $fn ]; then
	    cp $fn "${fn}-$arch"
	    if [ -z ${LOUT[$i]} ]; then
		LOUT[$i]=$fn
	    fi
	    LIPOS[$i]="${LIPOS[$i]} -arch $arch ${fn}-$arch"
	    i=$((i + 1))
	fi
    done
done
i=0
while [ $i -lt ${#LOUT[@]} ]; do
    echo lipo -create ${LIPOS[$i][@]} -output ${LOUT[$i]}
    lipo -create ${LIPOS[$i][@]} -output ${LOUT[$i]}
    i=$((i + 1))
done
rm -f $TOF
