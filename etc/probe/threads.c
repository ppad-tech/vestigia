/*
 * threads.c: a guest whose own thread reads what a second one has
 * done, a count it adds to between yields for as long as the host
 * lets it. The program's own thread is recorded alone, and runs alone
 * while the other waits, so two runs read the same count, and differ
 * nowhere.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 */
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>

static atomic_ulong count;

static void *work(void *p) {
  for (;;) {
    atomic_fetch_add(&count, 1);
    sched_yield();
  }
  return p;
}

int main(void) {
  pthread_t t;
  volatile unsigned long acc = 0;
  if (pthread_create(&t, NULL, work, NULL) != 0) return 1;
  for (unsigned long i = 0; i < 100000; i++) acc += i;
  unsigned long n = atomic_load(&count);
  for (unsigned long i = 0; i < n; i++) acc += i;
  return 0;
}
