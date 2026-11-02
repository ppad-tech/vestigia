/*
 * vestigia-init.c: the first process of a recorded run's own PID
 * namespace.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * Runs compared to find where a secret mattered must see the same
 * process, or a guest that keeps its pid (a random generator noting
 * it at seeding, to tell a fork) differs from run to run where no
 * secret did. QEMU's user mode gives the guest its own pid, so each
 * run is started in a PID namespace of its own (unshare), where this
 * is the first process and QEMU the second, in every run alike.
 *
 * QEMU is not made the first itself: the kernel discards a signal the
 * first process of a namespace sends itself without a handler for it,
 * and QEMU, delivering a guest a fatal signal, does just that, and
 * waits. This starts it, waits for it, and writes how it ended to
 * FILE: its exit status, or the signal that ended it, negated.
 *
 * usage: vestigia-init FILE PROGRAM [ARGUMENT...]
 */
#include <errno.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "usage: vestigia-init FILE PROGRAM [ARGUMENT...]\n");
    return 2;
  }

  pid_t pid = fork();
  if (pid == -1) {
    perror("vestigia-init: fork");
    return 2;
  }
  if (pid == 0) {
    execv(argv[2], argv + 2);
    perror("vestigia-init: exec");
    _exit(127);
  }

  int status;
  while (waitpid(pid, &status, 0) == -1) {
    if (errno != EINTR) {
      perror("vestigia-init: waitpid");
      return 2;
    }
  }

  FILE *f = fopen(argv[1], "w");
  if (f == NULL) {
    perror("vestigia-init: status");
    return 2;
  }
  if (WIFEXITED(status))
    fprintf(f, "%d\n", WEXITSTATUS(status));
  else if (WIFSIGNALED(status))
    fprintf(f, "%d\n", -WTERMSIG(status));
  else
    fprintf(f, "%d\n", 2);
  return fclose(f) == 0 ? 0 : 2;
}
