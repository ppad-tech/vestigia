/* A secret that reaches a branch, a load address, and a store
 * address, and a public value that reaches none: memcheck should
 * report the first three with a client-request origin. */
#include <stdio.h>
#include <string.h>
#include <valgrind/memcheck.h>

static unsigned char table[256];

__attribute__((noinline)) int branchy(unsigned char s) {
  if (s & 1) return 7;
  return 3;
}

__attribute__((noinline)) int lookup(unsigned char s) {
  return table[s];
}

__attribute__((noinline)) unsigned char ct(unsigned char s,
                                           unsigned char p) {
  unsigned char m = (unsigned char)(-(p & 1));
  return (unsigned char)((s & m) | (s ^ m));
}

int main(void) {
  unsigned char secret[4] = { 1, 2, 3, 4 };
  unsigned char out[4];
  memset(table, 5, sizeof table);
  VALGRIND_MAKE_MEM_UNDEFINED(secret, sizeof secret);
  out[0] = (unsigned char)branchy(secret[0]);
  out[1] = (unsigned char)lookup(secret[1]);
  out[2] = ct(secret[2], 1);
  table[secret[3]] = 9;
  VALGRIND_MAKE_MEM_DEFINED(out, sizeof out);
  printf("%d %d %d\n", out[0], out[1], out[2]);
  return 0;
}
