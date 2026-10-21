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
 * control flow are seen as well as those of data flow.
 *
 * It reads each instruction's bytes, x86_64's or aarch64's, for three
 * kinds. A return goes where the call before it sent it, and is
 * marked. An integer division takes a time that depends on its
 * operands, so it gets an order-sensitive fingerprint of their
 * values: the dividend and a register divisor read before it runs,
 * and a divisor in memory as it is loaded. A division run as often
 * but on other operands computed them from the secret. And a call,
 * with the returns, keeps a shadow stack of the calls in progress,
 * so that an instruction that could be an origin (one ending a
 * translation block, as every branch does, one touching memory, or a
 * division) is given the contexts it ran in: the chains of calls, by
 * their addresses, that reached it, up to CONTEXTS of them.
 *
 * At exit it writes, to the file named by its `out` argument:
 *
 *   I <pc> <count> <accesses> <fingerprint> <order> <object> <address>
 *   E <from> <to> <count>
 *   R <pc>
 *   D <pc> <operands>
 *   C <context> <caller> <call>
 *   K <pc> <partial> <context>...
 *
 * in hex, where <object> is the file the instruction's bytes were
 * mapped from ("-" if none, or if the file's program headers cannot
 * be read) and <address> its address in that file: where the file's
 * program headers place it, as its disassembly and line tables name
 * it. In a shared library that is often the instruction's offset in
 * the file; in an executable linked at a fixed address it is not. A
 * context is the call at <call> made in context <caller>, context 0
 * being the program's own; <partial> is 1 where an instruction ran in
 * more contexts than are kept. A guest that started a second thread
 * gets the line `T 2` alone.
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
enum { PLAIN, RETURN, DIVISION, CALL };

/* the most contexts kept for one instruction */
#define CONTEXTS 16

/* registers by number: x86_64's in ModRM order, aarch64's X0 to X30;
   aarch64's 31 is the zero register where a division names it */
enum { RAX = 0, RDX = 2, ZR = 31, GPRS = 32 };

typedef struct Decoded {
  int kind;
  /* a division's: its width in bits; on aarch64 its two registers,
     on x86_64 its divisor's (-1 in memory), that register's second
     byte where `high`, the dividend being RDX:RAX or AX */
  int width, a, b, high;
} Decoded;

typedef struct Insn {
  uint64_t pc;
  uint64_t size;
  uintptr_t haddr;
  Decoded d;
  uint64_t count;
  uint64_t accesses;
  uint64_t fingerprint;
  uint64_t order;   /* the successors, in the order they followed */
  uint64_t operands; /* a division's operands, in order */
  GHashTable *succ; /* target pc -> count, for transfers */
  uint32_t last;    /* the context it last ran in */
  uint32_t contexts[CONTEXTS];
  int ncontexts, partial;
  int origin;       /* it ends a block or divides: it could be one */
  /* a call's: the context it was last made in, and the one it made */
  uint32_t made_in, made;
} Insn;

/* a context: the context a call was made in, and the call */
typedef struct Context {
  uint32_t caller;
  uint64_t call;
} Context;

/* a call in progress: where it returns, and the context it left */
typedef struct Call {
  uint64_t ret;
  uint32_t left;
} Call;

static GHashTable *insns; /* pc -> Insn */
static Insn *prev;        /* the instruction executed last */
static char *out_path;
static gint vcpus;        /* the guest's threads, a vCPU each */
static gboolean aarch64;  /* the guest's ISA: aarch64, else x86_64 */
static GArray *contexts;  /* Context by number, 0 the program's own */
static GHashTable *interned; /* Context -> its number */
static GArray *calls;     /* the calls in progress, innermost last */
static uint32_t current;  /* the context the guest runs in */
static struct qemu_plugin_register *gpr[GPRS];
static GByteArray *regbuf;

static const uint64_t fnv_offset = 0xcbf29ce484222325ULL;
static const uint64_t fnv_prime = 0x100000001b3ULL;

static Decoded decode_aarch64(const uint8_t *b, size_t n) {
  Decoded d = { PLAIN, 0, 0, 0, 0 };
  uint32_t w;
  if (n < 4) return d;
  w = (uint32_t)b[0] | (uint32_t)b[1] << 8 | (uint32_t)b[2] << 16
      | (uint32_t)b[3] << 24;
  /* RET Xn, RETAA, RETAB */
  if ((w & 0xfffffc1f) == 0xd65f0000 || w == 0xd65f0bff
      || w == 0xd65f0fff)
    d.kind = RETURN;
  /* BL, BLR, BLRAAZ, BLRABZ, BLRAA, BLRAB */
  else if ((w & 0xfc000000) == 0x94000000
           || (w & 0xfffffc1f) == 0xd63f0000
           || (w & 0xfffff81f) == 0xd63f081f
           || (w & 0xfffff800) == 0xd73f0800)
    d.kind = CALL;
  /* UDIV, SDIV */
  else if ((w & 0x7fe0f800) == 0x1ac00800) {
    d.kind = DIVISION;
    d.width = (w >> 31) ? 64 : 32;
    d.a = (int)((w >> 5) & 31);
    d.b = (int)((w >> 16) & 31);
  }
  return d;
}

static Decoded decode_x86_64(const uint8_t *b, size_t n) {
  Decoded d = { PLAIN, 0, 0, 0, 0 };
  size_t k = 0;
  int opsize = 0, rex = 0;
  /* past the legacy prefixes, then a REX */
  while (k < n && (b[k] == 0x66 || b[k] == 0x67 || b[k] == 0xf0
                   || b[k] == 0xf2 || b[k] == 0xf3 || b[k] == 0x2e
                   || b[k] == 0x36 || b[k] == 0x3e || b[k] == 0x26
                   || b[k] == 0x64 || b[k] == 0x65)) {
    if (b[k] == 0x66) opsize = 1;
    k++;
  }
  if (k < n && (b[k] & 0xf0) == 0x40) rex = b[k++];
  if (k >= n) return d;
  /* RET, RET imm16 */
  if (b[k] == 0xc3 || b[k] == 0xc2) d.kind = RETURN;
  /* CALL rel32, CALL r/m: FF with ModRM's reg 2 */
  else if (b[k] == 0xe8
           || (b[k] == 0xff && k + 1 < n && ((b[k + 1] >> 3) & 7) == 2))
    d.kind = CALL;
  /* DIV, IDIV: F6 or F7 with ModRM's reg 6 or 7 */
  else if ((b[k] == 0xf6 || b[k] == 0xf7) && k + 1 < n
           && ((b[k + 1] >> 3) & 6) == 6) {
    int modrm = b[k + 1], rm = modrm & 7;
    d.kind = DIVISION;
    d.width = b[k] == 0xf6 ? 8 : (rex & 8) ? 64 : opsize ? 16 : 32;
    if ((modrm >> 6) != 3) d.a = -1;
    /* without REX, a byte register 4 to 7 is AH, CH, DH, or BH */
    else if (d.width == 8 && rex == 0 && rm >= 4) {
      d.a = rm - 4;
      d.high = 1;
    } else
      d.a = rm | ((rex & 1) << 3);
  }
  return d;
}

static Insn *insn_at(uint64_t pc, uint64_t size, uintptr_t haddr,
                     Decoded d) {
  Insn *i = g_hash_table_lookup(insns, &pc);
  if (i == NULL) {
    i = g_new0(Insn, 1);
    i->pc = pc;
    i->size = size;
    i->haddr = haddr;
    i->d = d;
    i->fingerprint = fnv_offset;
    i->order = fnv_offset;
    i->operands = fnv_offset;
    i->last = UINT32_MAX;
    i->made_in = UINT32_MAX;
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

static guint context_hash(gconstpointer p) {
  const Context *c = p;
  return (guint)((c->call * 0x9e3779b97f4a7c15ULL) >> 32) ^ c->caller;
}

static gboolean context_equal(gconstpointer a, gconstpointer b) {
  const Context *x = a, *y = b;
  return x->caller == y->caller && x->call == y->call;
}

static uint32_t context_of(uint32_t caller, uint64_t call) {
  Context c = { caller, call };
  gpointer v;
  if (g_hash_table_lookup_extended(interned, &c, NULL, &v))
    return GPOINTER_TO_UINT(v);
  uint32_t n = contexts->len;
  g_array_append_val(contexts, c);
  g_hash_table_insert(interned, g_memdup2(&c, sizeof c),
                      GUINT_TO_POINTER(n));
  return n;
}

/* a call made: it returns past itself */
static void enter(Insn *call) {
  Call c = { call->pc + call->size, current };
  g_array_append_val(calls, c);
  if (call->made_in != current) {
    call->made_in = current;
    call->made = context_of(current, call->pc);
  }
  current = call->made;
}

/* a return made, to pc: the innermost call returning there ends, and
   any inside it that never returned; a return no call made leaves
   the stack as it is */
static void leave(uint64_t pc) {
  for (guint k = calls->len; k > 0; k--) {
    const Call *c = &g_array_index(calls, Call, k - 1);
    if (c->ret == pc) {
      current = c->left;
      g_array_set_size(calls, k - 1);
      return;
    }
  }
}

static void note_context(Insn *i) {
  i->last = current;
  /* once more have been seen than are kept, no more is learnt */
  if (i->partial) return;
  for (int k = 0; k < i->ncontexts; k++)
    if (i->contexts[k] == current) return;
  if (i->ncontexts < CONTEXTS)
    i->contexts[i->ncontexts++] = current;
  else
    i->partial = 1;
}

static void on_exec(unsigned int vcpu, void *udata) {
  Insn *i = udata;
  (void)vcpu;
  if (prev != NULL) {
    prev->order = (prev->order ^ i->pc) * fnv_prime;
    if (i->pc != prev->pc + prev->size) transfer(prev, i->pc);
    if (prev->d.kind == CALL) enter(prev);
    else if (prev->d.kind == RETURN) leave(i->pc);
  }
  prev = i;
  i->count++;
  if (i->origin && i->last != current) note_context(i);
}

static void mix(Insn *i, uint64_t v) {
  i->operands = (i->operands ^ v) * fnv_prime;
}

static uint64_t read_gpr(int r) {
  uint64_t v = 0;
  int n;
  if (aarch64 && r == ZR) return 0;
  g_byte_array_set_size(regbuf, 0);
  n = qemu_plugin_read_register(gpr[r], regbuf);
  /* in the guest's byte order, little-endian as the host's */
  if (n > 0) memcpy(&v, regbuf->data, MIN((size_t)n, sizeof v));
  return v;
}

static void on_divide(unsigned int vcpu, void *udata) {
  Insn *i = udata;
  uint64_t mask = i->d.width == 64 ? ~0ULL : (1ULL << i->d.width) - 1;
  (void)vcpu;
  if (aarch64) {
    mix(i, read_gpr(i->d.a) & mask);
    mix(i, read_gpr(i->d.b) & mask);
    return;
  }
  if (i->d.width == 8)
    mix(i, read_gpr(RAX) & 0xffff);
  else {
    mix(i, read_gpr(RAX) & mask);
    mix(i, read_gpr(RDX) & mask);
  }
  /* a divisor in memory is mixed in as it is loaded */
  if (i->d.a >= 0)
    mix(i, (read_gpr(i->d.a) >> (i->d.high ? 8 : 0)) & mask);
}

static void on_mem(unsigned int vcpu, qemu_plugin_meminfo_t info,
                   uint64_t vaddr, void *udata) {
  Insn *i = udata;
  (void)vcpu;
  i->fingerprint = (i->fingerprint ^ vaddr) * fnv_prime;
  i->accesses++;
  if (i->last != current) note_context(i);
  if (i->d.kind == DIVISION) {
    qemu_plugin_mem_value v = qemu_plugin_mem_get_value(info);
    switch (v.type) {
    case QEMU_PLUGIN_MEM_VALUE_U8: mix(i, v.data.u8); break;
    case QEMU_PLUGIN_MEM_VALUE_U16: mix(i, v.data.u16); break;
    case QEMU_PLUGIN_MEM_VALUE_U32: mix(i, v.data.u32); break;
    case QEMU_PLUGIN_MEM_VALUE_U64: mix(i, v.data.u64); break;
    case QEMU_PLUGIN_MEM_VALUE_U128:
      mix(i, v.data.u128.low);
      mix(i, v.data.u128.high);
      break;
    }
  }
}

/* the general registers a division reads, by the names QEMU's
   debugger stub gives them */
static void find_registers(void) {
  static const char *x86_64[16] = {
    "rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
    "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15" };
  GArray *rs = qemu_plugin_get_registers();
  int wanted = aarch64 ? 31 : 16;
  for (guint k = 0; k < rs->len; k++) {
    qemu_plugin_reg_descriptor *r =
      &g_array_index(rs, qemu_plugin_reg_descriptor, k);
    for (int j = 0; j < wanted; j++) {
      char name[8];
      if (aarch64) g_snprintf(name, sizeof name, "x%d", j);
      if (strcmp(r->name, aarch64 ? name : x86_64[j]) == 0)
        gpr[j] = r->handle;
    }
  }
  g_array_free(rs, TRUE);
  for (int j = 0; j < wanted; j++)
    if (gpr[j] == NULL) {
      fprintf(stderr, "vestigia-qemu: QEMU names no register %d, by "
              "which a division's operands are read\n", j);
      _exit(EXIT_FAILURE);
    }
}

static void on_vcpu_init(qemu_plugin_id_t id, unsigned int vcpu) {
  (void)id;
  (void)vcpu;
  if (g_atomic_int_add(&vcpus, 1) == 0)
    find_registers();
  else {
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
                      aarch64 ? decode_aarch64(bytes, len)
                              : decode_x86_64(bytes, len));
    if (k == n - 1 || i->d.kind == DIVISION) i->origin = 1;
    qemu_plugin_register_vcpu_insn_exec_cb(qi, on_exec,
                                           QEMU_PLUGIN_CB_NO_REGS, i);
    if (i->d.kind == DIVISION)
      qemu_plugin_register_vcpu_insn_exec_cb(qi, on_divide,
                                             QEMU_PLUGIN_CB_R_REGS, i);
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
    if (i->d.kind == RETURN) fprintf(out, "R %" PRIx64 "\n", i->pc);
    if (i->d.kind == DIVISION)
      fprintf(out, "D %" PRIx64 " %016" PRIx64 "\n", i->pc, i->operands);
    if (i->ncontexts > 0) {
      fprintf(out, "K %" PRIx64 " %d", i->pc, i->partial);
      for (int k = 0; k < i->ncontexts; k++)
        fprintf(out, " %" PRIx32, i->contexts[k]);
      fprintf(out, "\n");
    }
    GHashTableIter jt;
    gpointer tk, tn;
    g_hash_table_iter_init(&jt, i->succ);
    while (g_hash_table_iter_next(&jt, &tk, &tn))
      fprintf(out, "E %" PRIx64 " %" PRIx64 " %" PRIx64 "\n", i->pc,
              *(uint64_t *)tk, *(uint64_t *)tn);
  }
  for (guint k = 1; k < contexts->len; k++) {
    const Context *c = &g_array_index(contexts, Context, k);
    fprintf(out, "C %x %" PRIx32 " %" PRIx64 "\n", k, c->caller,
            c->call);
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
  regbuf = g_byte_array_new();
  contexts = g_array_new(FALSE, FALSE, sizeof(Context));
  interned = g_hash_table_new_full(context_hash, context_equal, g_free,
                                   NULL);
  calls = g_array_new(FALSE, FALSE, sizeof(Call));
  {
    Context own = { 0, 0 };
    g_array_append_val(contexts, own);
  }
  qemu_plugin_register_vcpu_init_cb(id, on_vcpu_init);
  qemu_plugin_register_vcpu_tb_trans_cb(id, on_translate);
  qemu_plugin_register_atexit_cb(id, at_exit, NULL);
  return 0;
}
