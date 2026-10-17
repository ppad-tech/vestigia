/*
 * vestigia-ffi.c: vestigia's two marks as functions, for a harness
 * that reaches them through a foreign function interface (a Haskell
 * harness's `foreign import ccall`) rather than the header's inline
 * definitions.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 */
#include "vestigia.h"

void vestigia_secret_c(void *p, size_t n) { vestigia_secret(p, n); }
void vestigia_public_c(void *p, size_t n) { vestigia_public(p, n); }
