/*
 * env.c: a guest that marks a byte secret, then ends 0 only if its
 * environment holds VESTIGIA_PROBE_ENV=set, as a trace's env gives
 * it.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 */
#include <stdlib.h>
#include <string.h>

#include "vestigia.h"

static unsigned char secret = 1;

int main(void) {
  const char *v;
  vestigia_secret(&secret, 1);
  v = getenv("VESTIGIA_PROBE_ENV");
  return v != NULL && strcmp(v, "set") == 0 ? 0 : 1;
}
