/*
 * threads.c: a guest that starts a second thread, which the plugin
 * stops rather than record.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 */
#include <pthread.h>

static void *work(void *p) { return p; }

int main(void) {
  pthread_t t;
  if (pthread_create(&t, NULL, work, NULL) != 0) return 1;
  return pthread_join(t, NULL);
}
