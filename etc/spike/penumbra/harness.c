/*
 * Penumbra's three secret-key roots under vestigia: each call takes
 * fresh random secrets, marked secret before the call, with the
 * outputs Penumbra reveals marked public after it.
 *
 * usage: harness ROOT [RUNS]
 *   ROOT is public_key, key_agreement, or spend_auth_sign
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "vestigia.h"

void penumbra_audit_public_key(uint8_t *ws);
void penumbra_audit_key_agreement(uint8_t *ws);
void penumbra_audit_spend_auth_sign(uint8_t *ws);

static uint64_t state = 0x9e3779b97f4a7c15ULL;

static uint64_t splitmix(void) {
  uint64_t z = (state += 0x9e3779b97f4a7c15ULL);
  z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
  z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
  return z ^ (z >> 31);
}

static void fill(uint8_t *p, size_t n) {
  for (size_t i = 0; i < n; i++) p[i] = (uint8_t)splitmix();
}

/* a canonical scalar: random little-endian bytes with the top byte
 * cleared, below the decaf377 scalar modulus */
static void scalar(uint8_t *p) {
  fill(p, 32);
  p[31] = 0;
}

static void public_key(void) {
  uint8_t ws[64];
  scalar(ws);
  vestigia_secret(ws, 32);
  penumbra_audit_public_key(ws);
  vestigia_public(ws + 32, 32);
}

static void key_agreement(void) {
  uint8_t peer[64];
  uint8_t ws[96];
  scalar(peer);
  penumbra_audit_public_key(peer);
  scalar(ws);
  memcpy(ws + 32, peer + 32, 32);
  vestigia_secret(ws, 32);
  penumbra_audit_key_agreement(ws);
}

static void spend_auth_sign(void) {
  uint8_t ws[208];
  scalar(ws);
  fill(ws + 32, 80);
  fill(ws + 112, 32);
  /* the key and the signing randomness are secret; the message is
   * public */
  vestigia_secret(ws, 112);
  penumbra_audit_spend_auth_sign(ws);
  vestigia_public(ws + 144, 64);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: harness ROOT [RUNS]\n");
    return 2;
  }
  int runs = argc > 2 ? atoi(argv[2]) : 4;
  void (*root)(void) = NULL;
  if (strcmp(argv[1], "public_key") == 0) root = public_key;
  else if (strcmp(argv[1], "key_agreement") == 0) root = key_agreement;
  else if (strcmp(argv[1], "spend_auth_sign") == 0)
    root = spend_auth_sign;
  if (root == NULL) {
    fprintf(stderr, "unknown root: %s\n", argv[1]);
    return 2;
  }
  for (int i = 0; i < runs; i++) root();
  printf("%s: %d run(s)\n", argv[1], runs);
  return 0;
}
