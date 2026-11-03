/*
 * mark.c: a guest that reads its secret by branching on its digits,
 * then marks it and branches on it once. The trace begins at the
 * mark, so two runs on other secrets differ in the branch after it
 * alone.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * usage: mark SECRET   (SECRET: one byte of hex)
 */
#include <stdint.h>

#include "vestigia.h"

static uint8_t secret;

static int digit(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  return 0;
}

__attribute__((noinline)) static int after(uint8_t s) {
  volatile int r = 0;
  if (s & 0x80) r = 1;
  return r;
}

int main(int argc, char **argv) {
  if (argc != 2 || argv[1][0] == '\0') return 2;
  secret = (uint8_t)(digit(argv[1][0]) << 4 | digit(argv[1][1]));
  vestigia_secret(&secret, 1);
  return after(secret) & 0;
}
