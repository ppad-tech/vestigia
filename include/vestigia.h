/*
 * vestigia.h: the two marks a vestigia harness makes.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * vestigia_secret marks n bytes at p as secret: under memcheck they
 * become undefined, so every branch and address computed from them
 * is reported, with this mark as the origin. vestigia_public marks
 * n bytes at p as public again: outputs the function is meant to
 * reveal (a signature, a public key), so that writing them out is
 * not reported. Outside valgrind both are no-ops.
 *
 * Mark a secret after writing it and before the call; mark the
 * outputs after the call.
 */
#ifndef VESTIGIA_H
#define VESTIGIA_H

#include <stddef.h>
#include <valgrind/memcheck.h>

static inline void vestigia_secret(void *p, size_t n) {
  (void)VALGRIND_MAKE_MEM_UNDEFINED(p, n);
}

static inline void vestigia_public(void *p, size_t n) {
  (void)VALGRIND_MAKE_MEM_DEFINED(p, n);
}

#endif
