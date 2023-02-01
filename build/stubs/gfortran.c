/* simple driver-driver which dispatches based on the -arch <arch>
   argument to the corresponding <arch>-<build>-gfortran driver.

   NOTE: multiple -arch flags with different architectures are not
   supported (yet) since they require multiple runs and a lipo.

   Author: Simon Urbanek <simon.urbanek@R-project.org>
   License: MIT
*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#ifndef BUILD
#error "BUILD must be defined"
#endif

#ifdef __arm64__
#define myarch "arm64"
#endif
#ifdef __x86_64__
#define myarch "x86_64"
#endif
#ifndef myarch
#error "Unsupported architecture"
#endif

static char fn[512];

int main(int argc, char **argv) {
    int i = 1, j = 1, archs = 0;
    const char *arch = 0;
    while (i < argc) {
	if (!strcmp(argv[i], "-arch")) {
	    if (i + 1 < argc) {
		char *newarch = argv[++i];
		/* ignore duplicates */
		if (!arch || strcmp(arch, newarch)) {
		    arch = newarch;
		    archs++;
		}	  
	    } else {
		fprintf(stderr, "ERROR: <arch> missing in -arch");
		return 1;
	    }
	}
	i++;
    }
    if (archs > 1) {
	fprintf(stderr, "ERROR: Sorry, cannot handle multiple architectures at once, use multiple calls and lipo\n");
	return 1;
    }
    if (!arch)
	arch = myarch;
    if (!strcmp(arch, "arm64"))
	arch = "aarch64";
#ifdef PREFIX
    snprintf(fn, sizeof(fn), "%s/bin/%s-%s-gfortran", PREFIX, arch, BUILD);
#else
    snprintf(fn, sizeof(fn), "%s-%s-gfortran", arch, BUILD);
#endif
    argv[0] = fn;
    argv[argc] = 0;
    execvp(fn, argv);
    fprintf(stderr, "ERROR: cannot execute %s\n", fn);
    return 1;
}
