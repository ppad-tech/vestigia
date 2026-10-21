/*
 * harness.c: the harness the flake's probe check runs under both
 * instruments.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * Its secret, the first argument in hex (of one width for every
 * secret, so that runs lay out alike), reaches a loop's bound and a
 * table index; a constant-time select reaches neither.
 */
#include <stdio.h>
#include <stdlib.h>

#include "vestigia.h"

static unsigned char table[256];

__attribute__((noinline)) unsigned branchy(unsigned s) {
  unsigned r = 0;
  for (unsigned i = 0; i < (s & 7); i++) r += i;
  return r;
}

__attribute__((noinline)) unsigned lookup(unsigned s) {
  return table[s & 0xff];
}

__attribute__((noinline)) unsigned ct(unsigned s, unsigned p) {
  unsigned m = 0u - (p & 1u);
  return (s & m) | (~s & ~m);
}

int main(int argc, char **argv) {
  unsigned s = (unsigned)strtoul(argc > 1 ? argv[1] : "0", NULL, 16);
  unsigned out[3];
  for (int i = 0; i < 256; i++) table[i] = (unsigned char)i;
  vestigia_secret(&s, sizeof s);
  out[0] = branchy(s);
  out[1] = lookup(s);
  out[2] = ct(s, 1);
  vestigia_public(out, sizeof out);
  printf("%u %u %u\n", out[0], out[1], out[2]);
  return 0;
}
