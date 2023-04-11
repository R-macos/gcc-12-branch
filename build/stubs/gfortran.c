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

#ifdef PREFIX
/* prepend PREFIX so the prefix tools are found first */
static int add_PATH(const char *prefix) {
    char *path = getenv("PATH");
    size_t len = strlen(path) + strlen(PREFIX) + 8;
    char *npath = (char*) malloc(len);
    int n;
    if (!npath) {
	fprintf(stderr, "Out of memory.\n");
	return 1;
    }
    n = snprintf(npath, len, "%s/bin:%s", PREFIX, path);
    if (n > 0 && n < len)
	setenv("PATH", npath, 1);
    free(npath);
    return 0;
}

static int file_exists(const char *fn) {
    FILE *f = fopen(fn, "r");
    if (f) fclose(f);
    return f ? 1 : 0;
}
#endif

int main(int argc, char **argv) {
    int i = 1, j = 1, archs = 0;
    const char *arch = 0, *sdk;
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
    sdk = getenv("SDKROOT");
    if (sdk && !*sdk) sdk = 0;
    if (!sdk) { /* if there is no SDKROOT, check if the SDK link is correct */
	snprintf(fn, sizeof(fn), "%s/SDK/SDKSettings.plist", PREFIX);
	if (!file_exists(fn)) {
	    snprintf(fn, sizeof(fn), "%s/SDK/SDKSettings.json", PREFIX);
	    if (!file_exists(fn)) { /* invalid, detect SDK */
		FILE *f = popen("/usr/bin/xcrun --show-sdk-path", "r");
		if (!f || !fgets(fn, sizeof(fn), f)) {
		    fprintf(stderr, "** ERROR: %s/SDK is invalid and cannot determine SDK path!\n\n", PREFIX);
		    if (f) fclose(f);
		    return 1;
		} else {
		    char *c = strchr(fn, '\n');
		    fclose(f);
		    if (c) *c = 0;
		    if (*fn) {
			fprintf(stderr,"Warning: %s/SDK is invalid, setting SDKROOT=%s\n  Consider running the following to fix (or set SDKROOT):\n  ln -sfn %s %s/SDK\n", PREFIX, fn, fn, PREFIX);
			setenv("SDKROOT", fn, 1);
		    }
		}
	    }
	}
    }
    add_PATH(PREFIX);
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
