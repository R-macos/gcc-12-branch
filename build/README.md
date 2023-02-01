# GNU Fortran Universal Build

This directory contains the scripts used to build a fully universal
GNU Fortran for macOS. The scripts will build for the `/opt/gfortran`
destination with macOS 11 target and SDK. (Most scripts have a single
`prefix` parameter, but some don't). The build requires macOS 11
or higher and Apple silicon machine with Rosetta 2 installed.

The scripts are described in the order they should be run.

* `deps.sh` - downloads and builds GCC dependencies.
  They are built statically, so they do not need to be distributed
  with the compiler. They will be installed in the `deps`
  subdirectory.
  Note: for Rosetta 2 safety `gmp` is built with `westmere` target to
  avoid illegal instruction faults in Rosetta due to AVX.

* `build.sh` - builds GCC + GNU Fortran for all four combinations.
  
  The first step is to build stubs for all system tools,
  because cross-compilation requires `<arch>-<build>-<tool>` even
  though all tools are universal, so the stubs simply execute
  `/usr/bin/<tool>` instead (see the `stubs` directory).
  
  Then the native arm64 and x86_64 compilers are built (for simplicity
  we treat x86_64 as native) then the corresponding cross-compilers
  targetting the other architecture. The resulting directories have
  this structure:
  
  * `obj-<host_arch>-<target_arch>` location of the GCC build
  * `dst-<host_arch>-<target_arch>` location of the installation
  
  After each successful build the result is installed in the prefix
  location, becuase the cross-compiler build uses GCC built in the
  native step from the installed location.
  
  Note: all `@rpath`s are removed and replaced with target locations,
  becuase run-time libraries are notoriously fragile when using
  `@rpath` (works for the compilers, but not the run-time).
  
  `UPDATE=1` env var can be set in repeated calls to `build.sh` to
  avoid re-building already built `dst-*-*` directories.

* `mkuniversal.sh` - uses the `dst-*-*` directories to create a final
  `dst-universal` directory. It is based on the cross-compiled
  builds (because the native builds include `g++` which is not
  necessary and opens a whole can of worms we don't want). Then all
  binaries for the same target are `lipo`ed from both architectures -
  both the drivers in `bin` and `libexec`. Then the simple `gfortran`
  driver-driver is built (from `stubs`).

This process is more or less based on Apple's old `gcc` and the way we
created universal GNU Fortran back then for PowerPC and Intel, which
was copnceptually built this way. Unfortunately, the original
`driverdriver.c` can no longer be used, because the GCC driver API has
changed dramatically in 2010 so we provide a very rudimentary
driver-driver which only filters duplicate `-arch` flags and raises an
error if different archs are used.

An alternative `dr.sh` is provided to support multi-arch compilation
in one call via `-arch arm64 -arch x86_64`, but that is not
well-tested and instead of linking a full GCC driver, it relies on a
hack where the GCC driver will list output files into a file specified
by `_GCC_WRITE_OUTFILES` which are then `lipo`ed together.

Note: all builds use `--enable-version-specific-runtime-libs` to
ensure that both the native compilers and the cross-compilers use the
same run-time library locations. Technically, we could `lipo` both
`lib` locations into one (which is what we did when we used the native
prefix location), but the rationale is that not using the native
location is safer.

Simon Urbanek

February 2023
