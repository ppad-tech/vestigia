/* A secret chosen by the first argument (same width for every
 * secret, so the stack lays out the same) reaching a branch and a
 * table index, and a constant-time select that touches neither. */
#include <stdio.h>
#include <stdlib.h>

static unsigned char table[256];

__attribute__((noinline)) int branchy(unsigned s) {
  int r = 0;
  for (unsigned i = 0; i < (s & 7); i++) r += i;
  return r;
}

__attribute__((noinline)) int lookup(unsigned s) {
  return table[s & 0xff];
}

__attribute__((noinline)) unsigned ct(unsigned s, unsigned p) {
  unsigned m = 0u - (p & 1u);
  return (s & m) | (s ^ m);
}

int main(int argc, char **argv) {
  unsigned s = (unsigned)strtoul(argc > 1 ? argv[1] : "00", NULL, 16);
  for (int i = 0; i < 256; i++) table[i] = (unsigned char)i;
  int a = branchy(s);
  int b = lookup(s);
  unsigned c = ct(s, 1);
  printf("%d %d %u\n", a, b, c);
  return 0;
}
