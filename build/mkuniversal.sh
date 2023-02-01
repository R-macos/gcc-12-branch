#!/bin/sh

## FIXME: this script uses fixed prefix /opt/gfortran

set -e

rm -rf dst-universal
mkdir dst-universal

## use the cross-builds as base since they are smaller
## as they don't include gcc
echo Copy arm64 target
rsync -a dst-x86_64-arm64/ dst-universal/
echo Copy x86_64 target
rsync -a dst-arm64-x86_64/ dst-universal/

gccv=`ls dst-universal/opt/gfortran/bin/*-gcc-1*`
## replace unversioned gcc with a symlink
for i in $gccv; do
    ii=$(echo $i | sed -E 's:-[^-]+$::')
    ln -sfn $(basename $i) $ii
done

echo lipo x86_64 target in bin
for i in  `find dst-universal/opt/gfortran/bin -type f|grep x86_64`; do
    j=$(echo $i|sed s:^dst-universal/::)
    b=$(echo $j|sed -E 's:.*darwin[^-]+-::')
    xf=dst-x86_64-x86_64/$j
    ## some native tools don't have prefix
    if [ ! -e $xf ]; then
	xf=$(dirname $xf)/$b
    fi
    lipo -create -arch arm64 dst-arm64-x86_64/$j -arch x86_64 $xf -output $i
done

echo lipo arm64 target in bin
for i in `find dst-universal/opt/gfortran/bin -type f|grep aarch64`; do
    j=$(echo $i|sed s:^dst-universal/::)
    b=$(echo $j|sed -E 's:.*darwin[^-]+-::')
    xf=dst-arm64-arm64/$j
    if [ ! -e $xf ]; then
	xf=$(dirname $xf)/$b
    fi
    lipo -create -arch arm64 $xf -arch x86_64 dst-x86_64-arm64/$j -output $i
done

## lipo the only thing in the global space: libcc*.so
lipo -create \
     -arch arm64 dst-arm64-arm64/opt/gfortran/lib/libcc1.0.so \
     -arch x86_64 dst-x86_64-x86_64/opt/gfortran/lib/libcc1.0.so \
     -output dst-universal/opt/gfortran/lib/libcc1.0.so

echo lipo libexec tools
## lipo all binary tools
for i in `find dst-universal/opt/gfortran/libexec -type f`; do
    if file $i | grep Mach-O >/dev/null; then
	xarch=$(file $i|sed 's:.* ::')
	ii=$(echo $i | sed -E 's:^[^/]+/::')
	if [ $xarch == arm64 ]; then farch=x86_64; else farch=arm64; fi
	lipo -create \
	     -arch arm64 dst-arm64-$farch/$ii \
	     -arch x86_64 dst-x86_64-$farch/$ii \
	     -output $i
    fi
done

echo Compile driver
clang -DPREFIX=\"/opt/gfortran\" -DBUILD=\"apple-darwin20.0\" -arch arm64 -arch x86_64 -O3 -o dst-universal/opt/gfortran/bin/gfortran stubs/gfortran.c

echo Link SDK $(readlink /opt/gfortran/SDK)
ln -s $(readlink /opt/gfortran/SDK) dst-universal/opt/gfortran/SDK

echo Copy stubs
cp -p stubs/[ax]* dst-universal/opt/gfortran/bin
