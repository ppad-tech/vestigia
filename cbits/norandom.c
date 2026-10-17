/*
 * norandom.c: address-space randomisation off for this process and
 * every process it starts.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * Runs compared to find where a secret mattered must lay memory out
 * alike, or every address differs between them and none of the
 * differences means anything. The personality is inherited across
 * fork and exec, so setting it before starting QEMU covers the guest.
 */
#ifdef __linux__
#include <sys/personality.h>

int vestigia_no_randomize(void) {
  int p = personality(0xffffffff);
  if (p == -1) return -1;
  return personality((unsigned long)p | ADDR_NO_RANDOMIZE) == -1 ? -1 : 0;
}
#else
int vestigia_no_randomize(void) { return -1; }
#endif
