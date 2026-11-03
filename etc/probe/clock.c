/*
 * clock.c: a guest that decides by time, spinning until a millisecond
 * has passed on its clock. Its thread's clock advances by its own
 * readings alone, so two runs spin alike.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 */
#include <time.h>

static unsigned long now(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (unsigned long)ts.tv_sec * 1000000000UL
    + (unsigned long)ts.tv_nsec;
}

int main(void) {
  unsigned long start = now();
  volatile unsigned long n = 0;
  while (now() - start < 1000000) n++;
  return 0;
}
