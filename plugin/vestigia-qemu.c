/*
 * vestigia-qemu.c: a QEMU user-mode plugin recording a run's leakage
 * trace, summarised per instruction.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * For every guest instruction executed it records how many times it
 * ran, every non-sequential transfer out of it (a branch taken, a
 * call, a jump, a return) with its count, and an order-sensitive
 * fingerprint of the data addresses it touched. Two runs of a
 * program that differ only in a secret then differ exactly where
 * the execution depended on the secret: a transfer whose counts
 * differ is a secret-dependent branch, and an instruction run as
 * often but touching other addresses computed one from the secret.
 * Nothing needs aligning, and no taint is propagated, so effects of
 * control flow are seen as well as those of data flow.
 *
 * At exit it writes, to the file named by its `out` argument:
 *
 *   I <pc> <count> <accesses> <fingerprint> <object> <offset>
 *   E <from> <to> <count>
 *
 * in hex, where <object> is the file the instruction's bytes were
 * mapped from ("-" if none) and <offset> its offset in that file.
 *
 * A single-threaded guest is assumed: the state below is unlocked.
 */
#include <glib.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <qemu-plugin.h>

QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

typedef struct Insn {
  uint64_t pc;
  uint64_t size;
  uintptr_t haddr;
  uint64_t count;
  uint64_t accesses;
  uint64_t fingerprint;
  GHashTable *succ; /* target pc -> count, for transfers */
} Insn;

static GHashTable *insns; /* pc -> Insn */
static Insn *prev;        /* the instruction executed last */
static char *out_path;

static const uint64_t fnv_offset = 0xcbf29ce484222325ULL;
static const uint64_t fnv_prime = 0x100000001b3ULL;

static Insn *insn_at(uint64_t pc, uint64_t size, uintptr_t haddr) {
  Insn *i = g_hash_table_lookup(insns, &pc);
  if (i == NULL) {
    i = g_new0(Insn, 1);
    i->pc = pc;
    i->size = size;
    i->haddr = haddr;
    i->fingerprint = fnv_offset;
    i->succ = g_hash_table_new_full(g_int64_hash, g_int64_equal,
                                    g_free, g_free);
    g_hash_table_insert(insns, &i->pc, i);
  }
  return i;
}

static void transfer(Insn *from, uint64_t to) {
  uint64_t *n = g_hash_table_lookup(from->succ, &to);
  if (n == NULL) {
    uint64_t *k = g_new(uint64_t, 1);
    *k = to;
    n = g_new0(uint64_t, 1);
    g_hash_table_insert(from->succ, k, n);
  }
  (*n)++;
}

static void on_exec(unsigned int vcpu, void *udata) {
  Insn *i = udata;
  (void)vcpu;
  if (prev != NULL && i->pc != prev->pc + prev->size)
    transfer(prev, i->pc);
  prev = i;
  i->count++;
}

static void on_mem(unsigned int vcpu, qemu_plugin_meminfo_t info,
                   uint64_t vaddr, void *udata) {
  Insn *i = udata;
  (void)vcpu;
  (void)info;
  i->fingerprint = (i->fingerprint ^ vaddr) * fnv_prime;
  i->accesses++;
}

static void on_translate(qemu_plugin_id_t id, struct qemu_plugin_tb *tb) {
  size_t n = qemu_plugin_tb_n_insns(tb);
  (void)id;
  for (size_t k = 0; k < n; k++) {
    struct qemu_plugin_insn *qi = qemu_plugin_tb_get_insn(tb, k);
    Insn *i = insn_at(qemu_plugin_insn_vaddr(qi),
                      qemu_plugin_insn_size(qi),
                      (uintptr_t)qemu_plugin_insn_haddr(qi));
    qemu_plugin_register_vcpu_insn_exec_cb(qi, on_exec,
                                           QEMU_PLUGIN_CB_NO_REGS, i);
    qemu_plugin_register_vcpu_mem_cb(qi, on_mem, QEMU_PLUGIN_CB_NO_REGS,
                                     QEMU_PLUGIN_MEM_RW, i);
  }
}

/* the host's file-backed mappings, for naming an instruction's file */
typedef struct Region {
  uintptr_t start, end;
  uint64_t offset;
  char *path;
} Region;

static GArray *read_maps(void) {
  GArray *rs = g_array_new(FALSE, FALSE, sizeof(Region));
  FILE *f = fopen("/proc/self/maps", "r");
  char line[4096];
  if (f == NULL) return rs;
  while (fgets(line, sizeof line, f) != NULL) {
    uintptr_t start, end;
    uint64_t offset;
    char perms[8], dev[16];
    unsigned long inode;
    int used = 0;
    if (sscanf(line, "%" SCNxPTR "-%" SCNxPTR " %7s %" SCNx64
               " %15s %lu %n", &start, &end, perms, &offset, dev,
               &inode, &used) < 6)
      continue;
    char *path = line + used;
    path[strcspn(path, "\n")] = '\0';
    if (inode == 0 || path[0] != '/') continue;
    Region r = { start, end, offset, g_strdup(path) };
    g_array_append_val(rs, r);
  }
  fclose(f);
  return rs;
}

static const Region *region_of(GArray *rs, uintptr_t a) {
  for (guint k = 0; k < rs->len; k++) {
    const Region *r = &g_array_index(rs, Region, k);
    if (a >= r->start && a < r->end) return r;
  }
  return NULL;
}

static void at_exit(qemu_plugin_id_t id, void *p) {
  (void)id;
  (void)p;
  FILE *out = fopen(out_path, "w");
  if (out == NULL) {
    fprintf(stderr, "vestigia-qemu: cannot write %s\n", out_path);
    return;
  }
  GArray *rs = read_maps();
  GHashTableIter it;
  gpointer key, val;
  g_hash_table_iter_init(&it, insns);
  while (g_hash_table_iter_next(&it, &key, &val)) {
    Insn *i = val;
    const Region *r = region_of(rs, i->haddr);
    if (r != NULL)
      fprintf(out, "I %" PRIx64 " %" PRIx64 " %" PRIx64 " %016" PRIx64
              " %s %" PRIx64 "\n", i->pc, i->count, i->accesses,
              i->fingerprint, r->path,
              (uint64_t)(i->haddr - r->start) + r->offset);
    else
      fprintf(out, "I %" PRIx64 " %" PRIx64 " %" PRIx64 " %016" PRIx64
              " - 0\n", i->pc, i->count, i->accesses, i->fingerprint);
    GHashTableIter jt;
    gpointer tk, tn;
    g_hash_table_iter_init(&jt, i->succ);
    while (g_hash_table_iter_next(&jt, &tk, &tn))
      fprintf(out, "E %" PRIx64 " %" PRIx64 " %" PRIx64 "\n", i->pc,
              *(uint64_t *)tk, *(uint64_t *)tn);
  }
  fclose(out);
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id,
                                           const qemu_info_t *info,
                                           int argc, char **argv) {
  (void)info;
  for (int k = 0; k < argc; k++)
    if (strncmp(argv[k], "out=", 4) == 0)
      out_path = g_strdup(argv[k] + 4);
  if (out_path == NULL) {
    fprintf(stderr, "vestigia-qemu: an out=FILE argument is needed\n");
    return -1;
  }
  insns = g_hash_table_new(g_int64_hash, g_int64_equal);
  qemu_plugin_register_vcpu_tb_trans_cb(id, on_translate);
  qemu_plugin_register_atexit_cb(id, at_exit, NULL);
  return 0;
}
