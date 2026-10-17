/*
 * vestigia.c: the marks vestigia.h declares.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * A site is reported at a run-time address, and only the loader
 * knows where it put the object holding it. On Linux, when the
 * environment names a file in VESTIGIA_OBJECTS (vestigia sets it),
 * the first secret mark writes there each loaded object's load bias
 * and path, so a site can be named by its object and its address in
 * it. That needs dl_iterate_phdr, which glibc declares only under
 * _GNU_SOURCE, set here before any header can settle the feature
 * set; this is why the marks are a compilation unit, not a header.
 */
#ifdef __linux__
#define _GNU_SOURCE
#include <link.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#endif

#include <valgrind/memcheck.h>

#include "vestigia.h"

#ifdef __linux__
static int object_(struct dl_phdr_info *info, size_t size, void *data) {
  FILE *f = data;
  char exe[4096];
  const char *name = info->dlpi_name;
  (void)size;
  /* the main program is listed unnamed */
  if (name == NULL || name[0] == '\0') {
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    if (n <= 0) return 0;
    exe[n] = '\0';
    name = exe;
  }
  fprintf(f, "%lx %s\n", (unsigned long)info->dlpi_addr, name);
  return 0;
}

static void objects_(void) {
  static int written = 0;
  const char *path;
  FILE *f;
  if (written) return;
  written = 1;
  path = getenv("VESTIGIA_OBJECTS");
  if (path == NULL) return;
  f = fopen(path, "w");
  if (f == NULL) return;
  dl_iterate_phdr(object_, f);
  fclose(f);
}
#else
static void objects_(void) {}
#endif

void vestigia_secret(void *p, size_t n) {
  objects_();
  (void)VALGRIND_MAKE_MEM_UNDEFINED(p, n);
}

void vestigia_public(void *p, size_t n) {
  (void)VALGRIND_MAKE_MEM_DEFINED(p, n);
}
