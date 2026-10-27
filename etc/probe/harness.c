/*
 * harness.c: the harness the flake's probe check runs under both
 * instruments.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * Its secret, the first argument in hex (of one width for every
 * secret, so that runs lay out alike), reaches a loop's bound, a
 * table index, which of two calls a helper returns to, a dividend,
 * a divisor, a floating-point division (outside either ISA's
 * data-independent-timing contract), and, on a path the third secret
 * alone takes, another table index; a constant-time select reaches
 * none of them.
 */
#include <stdio.h>
#include <stdlib.h>

#include "vestigia.h"

static unsigned char table[256];
static volatile unsigned modulus = 3329;

__attribute__((noinline)) unsigned branchy(unsigned s) {
  unsigned r = 0;
  for (unsigned i = 0; i < (s & 7); i++) r += i;
  return r;
}

__attribute__((noinline)) unsigned lookup(unsigned s) {
  return table[s & 0xff];
}

__attribute__((noinline)) unsigned leaf(unsigned x) {
  return x * 3u + 1u;
}

/* leaf runs eight times whatever the secret, but returns to one call
   or the other as the secret's bits say */
__attribute__((noinline)) unsigned calls(unsigned s) {
  unsigned r = 0;
  for (unsigned i = 0; i < 8; i++) {
    if ((s >> i) & 1u) r += leaf(i);
    else r ^= leaf(i + 1u);
  }
  return r;
}

/* a secret divided by a public modulus, the divisor in a register */
__attribute__((noinline)) unsigned divide(unsigned s) {
#if defined(__x86_64__)
  unsigned q, r;
  __asm__ volatile("divl %4"
                   : "=a"(q), "=d"(r)
                   : "a"(s * 2654435761u), "d"(0u), "r"(modulus));
  return q ^ r;
#else
  return (s * 2654435761u) / modulus;
#endif
}

/* a public value divided by a secret, which x86_64 reads from memory
   as the division's operand */
__attribute__((noinline)) unsigned divide_memory(unsigned s) {
  unsigned d = (s & 0xffu) | 1u;
#if defined(__x86_64__)
  unsigned q, r;
  __asm__ volatile("divl %4"
                   : "=a"(q), "=d"(r)
                   : "a"(1000003u), "d"(0u), "m"(d));
  return q ^ r;
#else
  return 1000003u / d;
#endif
}

/* a secret divided in floating point, which neither Arm's DIT nor
   Intel's DOITM covers */
__attribute__((noinline)) unsigned fpdivide(unsigned s) {
  return (unsigned)((double)s / 7.0);
}

/* a table index on a path one secret takes */
__attribute__((noinline)) unsigned rare(unsigned s) {
  if ((s & 0xffu) == 0xc3u) return table[(s >> 1) & 0xffu];
  return 0;
}

__attribute__((noinline)) unsigned ct(unsigned s, unsigned p) {
  unsigned m = 0u - (p & 1u);
  return (s & m) | (~s & ~m);
}

int main(int argc, char **argv) {
  unsigned s = (unsigned)strtoul(argc > 1 ? argv[1] : "0", NULL, 16);
  unsigned out[8];
  for (int i = 0; i < 256; i++) table[i] = (unsigned char)i;
  vestigia_secret(&s, sizeof s);
  out[0] = branchy(s);
  out[1] = lookup(s);
  out[2] = calls(s);
  out[3] = divide(s);
  out[4] = divide_memory(s);
  out[5] = rare(s);
  out[6] = ct(s, 1);
  out[7] = fpdivide(s);
  vestigia_public(out, sizeof out);
  printf("%u %u %u %u %u %u %u %u\n", out[0], out[1], out[2], out[3],
         out[4], out[5], out[6], out[7]);
  return 0;
}
