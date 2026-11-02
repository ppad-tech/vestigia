/*
 * pid.c: a guest whose path follows its pid, as a guest that keeps
 * its pid (a random generator noting it at seeding) is led by it,
 * and a guest a signal ends.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * Two runs of the first must differ nowhere, each seeing one pid;
 * the second must end its run as the signal does (record), not wait.
 * Built twice: as `pid`, and with -DABORT as `abort`.
 */
#include <stdlib.h>
#include <unistd.h>

static volatile int kept;

int main(void) {
#ifdef ABORT
  abort();
#else
  for (pid_t p = getpid() % 1024; p > 0; p--)
    kept++;
  return 0;
#endif
}
