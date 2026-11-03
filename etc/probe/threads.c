/*
 * threads.c: a guest that starts a second thread, which spins for as
 * long as the host lets it while the program's own thread does a
 * fixed amount of work. The plugin records the program's own thread
 * alone, so two runs differ nowhere.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 */
#include <pthread.h>
#include <stdatomic.h>

static atomic_int done;
static volatile unsigned long spins;

static void *work(void *p) {
  while (!atomic_load(&done)) spins++;
  return p;
}

int main(void) {
  pthread_t t;
  volatile unsigned long acc = 0;
  if (pthread_create(&t, NULL, work, NULL) != 0) return 1;
  for (unsigned long i = 0; i < 100000; i++) acc += i;
  atomic_store(&done, 1);
  return pthread_join(t, NULL);
}
