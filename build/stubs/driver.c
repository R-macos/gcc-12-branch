#include <unistd.h>

extern char **environ;

#ifndef PROG
#error "PROG must be defined"
#endif

int main(int argc, char **argv) {
  argv[argc] = 0;
  return execve("/usr/bin/" PROG, argv, environ);
}
