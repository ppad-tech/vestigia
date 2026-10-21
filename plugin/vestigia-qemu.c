/*
 * vestigia-qemu.c: a QEMU user-mode plugin recording a run's leakage
 * trace, summarised per instruction.
 *
 * Copyright (c) 2026 Jared Tobin
 * License: MIT
 *
 * For every guest instruction executed it records how many times it
 * ran, every non-sequential transfer out of it (a branch taken, a
 * call, a jump, a return) with its count, an order-sensitive
 * fingerprint of the data addresses it touched, and an order-
 * sensitive fingerprint of the instructions that followed it. Two
 * runs of a program that differ only in a secret then differ exactly
 * where the execution depended on the secret: a transfer whose counts
 * differ is a secret-dependent branch, as is one taking the same
 * transfers as often in another order, and an instruction run as
 * often but touching other addresses computed one from the secret.
 * Nothing needs aligning, and no taint is propagated, so effects of
 * control flow are seen as well as those of data flow. It marks the
 * instructions that return (x86_64's and aarch64's), which go where
 * the call before them sent them.
 *
 * At exit it writes, to the file named by its `out` argument:
 *
 *   I <pc> <count> <accesses> <fingerprint> <order> <object> <address>
 *   E <from> <to> <count>
 *   R <pc>
 *
 * or, for a guest that started a second thread, the line `T 2` alone.
 *
 * in hex, where <object> is the file the instruction's bytes were
 * mapped from ("-" if none, or if the file's program headers cannot
 * be read) and <address> its address in that file: where the file's
 * program headers place it, as its disassembly and line tables name
 * it. In a shared library that is often the instruction's offset in
 * the file; in an executable linked at a fixed address it is not.
 *
 * The state below is unlocked, so one guest thread is recorded: a
 * guest that starts a second one is stopped there, its dump saying
 * so, rather than recorded by threads racing on it.
 */
#include <elf.h>
#include <glib.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <qemu-plugin.h>

QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

/* what an instruction is to a comparison, read from its bytes */
enum { PLAIN, RETURN };

typedef struct Insn {
  uint64_t pc;
  uint64_t size;
  uintptr_t haddr;
  int kind;
  uint64_t count;
  uint64_t accesses;
  uint64_t fingerprint;
  uint64_t order;   /* the successors, in the order they followed */
  GHashTable *succ; /* target pc -> count, for transfers */
} Insn;

static GHashTable *insns; /* pc -> Insn */
static Insn *prev;        /* the instruction executed last */
static char *out_path;
static gint vcpus;        /* the guest's threads, a vCPU each */
static gboolean aarch64;  /* the guest's ISA: aarch64, else x86_64 */

static const uint64_t fnv_offset = 0xcbf29ce484222325ULL;
static const uint64_t fnv_prime = 0x100000001b3ULL;

/* an x86_64 instruction's opcode: past its legacy and REX prefixes */
static size_t x86_opcode(const uint8_t *b, size_t n) {
  size_t k = 0;
  while (k < n && (b[k] == 0x66 || b[k] == 0x67 || b[k] == 0xf0
                   || b[k] == 0xf2 || b[k] == 0xf3 || b[k] == 0x2e
                   || b[k] == 0x36 || b[k] == 0x3e || b[k] == 0x26
                   || b[k] == 0x64 || b[k] == 0x65))
    k++;
  if (k < n && (b[k] & 0xf0) == 0x40) k++;
  return k;
}

static int kind_of(const uint8_t *b, size_t n) {
  if (aarch64) {
    uint32_t w;
    if (n < 4) return PLAIN;
    w = (uint32_t)b[0] | (uint32_t)b[1] << 8 | (uint32_t)b[2] << 16
        | (uint32_t)b[3] << 24;
    /* RET Xn, RETAA, RETAB */
    if ((w & 0xfffffc1f) == 0xd65f0000 || w == 0xd65f0bff
        || w == 0xd65f0fff)
      return RETURN;
    return PLAIN;
  } else {
    size_t k = x86_opcode(b, n);
    /* RET, RET imm16 */
    if (k < n && (b[k] == 0xc3 || b[k] == 0xc2)) return RETURN;
    return PLAIN;
  }
}

static Insn *insn_at(uint64_t pc, uint64_t size, uintptr_t haddr,
                     int kind) {
  Insn *i = g_hash_table_lookup(insns, &pc);
  if (i == NULL) {
    i = g_new0(Insn, 1);
    i->pc = pc;
    i->size = size;
    i->haddr = haddr;
    i->kind = kind;
    i->fingerprint = fnv_offset;
    i->order = fnv_offset;
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
  if (prev != NULL) {
    prev->order = (prev->order ^ i->pc) * fnv_prime;
    if (i->pc != prev->pc + prev->size) transfer(prev, i->pc);
  }
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

static void on_vcpu_init(qemu_plugin_id_t id, unsigned int vcpu) {
  (void)id;
  (void)vcpu;
  if (g_atomic_int_add(&vcpus, 1) > 0) {
    FILE *out = fopen(out_path, "w");
    if (out != NULL) {
      fprintf(out, "T 2\n");
      fclose(out);
    }
    fprintf(stderr, "vestigia-qemu: the guest started a second thread, "
            "which a trace cannot record; the run is stopped\n");
    _exit(EXIT_FAILURE);
  }
}

static void on_translate(qemu_plugin_id_t id, struct qemu_plugin_tb *tb) {
  size_t n = qemu_plugin_tb_n_insns(tb);
  (void)id;
  for (size_t k = 0; k < n; k++) {
    struct qemu_plugin_insn *qi = qemu_plugin_tb_get_insn(tb, k);
    uint8_t bytes[16];
    size_t len = qemu_plugin_insn_data(qi, bytes, sizeof bytes);
    Insn *i = insn_at(qemu_plugin_insn_vaddr(qi),
                      qemu_plugin_insn_size(qi),
                      (uintptr_t)qemu_plugin_insn_haddr(qi),
                      kind_of(bytes, len));
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

/* a file's loadable segments, by which a file offset is placed at
   the address the file's own disassembly gives it */
typedef struct Segments {
  guint n;
  Elf64_Phdr *load;
} Segments;

static Segments *read_segments(const char *path) {
  FILE *f = fopen(path, "rb");
  Elf64_Ehdr eh;
  Segments *s = NULL;
  if (f == NULL) return NULL;
  /* a little-endian ELF64 object, as x86_64 and aarch64 build */
  if (fread(&eh, sizeof eh, 1, f) != 1
      || memcmp(eh.e_ident, ELFMAG, SELFMAG) != 0
      || eh.e_ident[EI_CLASS] != ELFCLASS64
      || eh.e_ident[EI_DATA] != ELFDATA2LSB
      || eh.e_phentsize != sizeof(Elf64_Phdr)
      || fseek(f, (long)eh.e_phoff, SEEK_SET) != 0) {
    fclose(f);
    return NULL;
  }
  s = g_new0(Segments, 1);
  s->load = g_new0(Elf64_Phdr, eh.e_phnum);
  for (guint k = 0; k < eh.e_phnum; k++) {
    Elf64_Phdr ph;
    if (fread(&ph, sizeof ph, 1, f) != 1) {
      g_free(s->load);
      g_free(s);
      fclose(f);
      return NULL;
    }
    if (ph.p_type == PT_LOAD) s->load[s->n++] = ph;
  }
  fclose(f);
  return s;
}

/* the segments of the file at a path, read once; NULL if they cannot
   be read, which is said once */
static Segments *segments_of(GHashTable *cache, const char *path) {
  gpointer v;
  if (g_hash_table_lookup_extended(cache, path, NULL, &v)) return v;
  Segments *s = read_segments(path);
  if (s == NULL)
    fprintf(stderr, "vestigia-qemu: cannot read the program headers "
            "of %s; its instructions are named by no object\n", path);
  g_hash_table_insert(cache, g_strdup(path), s);
  return s;
}

/* where a file's segments place the byte at a file offset */
static gboolean address_in(const Segments *s, uint64_t off,
                           uint64_t *addr) {
  for (guint k = 0; k < s->n; k++) {
    const Elf64_Phdr *p = &s->load[k];
    if (off >= p->p_offset && off - p->p_offset < p->p_filesz) {
      *addr = p->p_vaddr + (off - p->p_offset);
      return TRUE;
    }
  }
  return FALSE;
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
  GHashTable *segs = g_hash_table_new(g_str_hash, g_str_equal);
  GHashTableIter it;
  gpointer key, val;
  g_hash_table_iter_init(&it, insns);
  while (g_hash_table_iter_next(&it, &key, &val)) {
    Insn *i = val;
    const Region *r = region_of(rs, i->haddr);
    Segments *s = r != NULL ? segments_of(segs, r->path) : NULL;
    uint64_t addr;
    if (s != NULL
        && address_in(s, (uint64_t)(i->haddr - r->start) + r->offset,
                      &addr))
      fprintf(out, "I %" PRIx64 " %" PRIx64 " %" PRIx64 " %016" PRIx64
              " %016" PRIx64 " %s %" PRIx64 "\n", i->pc, i->count,
              i->accesses, i->fingerprint, i->order, r->path, addr);
    else
      fprintf(out, "I %" PRIx64 " %" PRIx64 " %" PRIx64 " %016" PRIx64
              " %016" PRIx64 " - 0\n", i->pc, i->count, i->accesses,
              i->fingerprint, i->order);
    if (i->kind == RETURN) fprintf(out, "R %" PRIx64 "\n", i->pc);
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
  aarch64 = strcmp(info->target_name, "aarch64") == 0;
  for (int k = 0; k < argc; k++)
    if (strncmp(argv[k], "out=", 4) == 0)
      out_path = g_strdup(argv[k] + 4);
  if (out_path == NULL) {
    fprintf(stderr, "vestigia-qemu: an out=FILE argument is needed\n");
    return -1;
  }
  insns = g_hash_table_new(g_int64_hash, g_int64_equal);
  qemu_plugin_register_vcpu_init_cb(id, on_vcpu_init);
  qemu_plugin_register_vcpu_tb_trans_cb(id, on_translate);
  qemu_plugin_register_atexit_cb(id, at_exit, NULL);
  return 0;
}
