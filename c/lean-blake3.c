#include "lean/lean.h"
#include "blake3.h"

static lean_object* l_blake3_version() {
  const char * v = blake3_version();
  lean_obj_res r = lean_mk_string(v);
  return r;
}

extern blake3_hasher * blake3_hasher_copy(blake3_hasher *self);
extern void blake3_hasher_update(blake3_hasher *self, const void *input, size_t input_len);
extern void blake3_hasher_free(blake3_hasher *self);

static lean_external_class *g_blake3_hasher_external_class = NULL;

static void blake3_hasher_finalizer(void *ptr) {
  blake3_hasher_free(ptr);
}

inline static void blake3_hasher_foreach(void *mod, b_lean_obj_arg fn) {}

lean_obj_res blake3_initialize() {
  g_blake3_hasher_external_class = lean_register_external_class(blake3_hasher_finalizer, blake3_hasher_foreach);
  return lean_io_result_mk_ok(lean_box(0));
}

static inline lean_obj_res lean_ensure_exclusive_blake3_hasher(lean_obj_arg a) {
    if (lean_is_exclusive(a)) return a;
    return lean_alloc_external(g_blake3_hasher_external_class, blake3_hasher_copy(a));
}

lean_obj_res lean_blake3_hasher_update(lean_obj_arg self, b_lean_obj_arg input, size_t input_len) {
  lean_object* a = lean_ensure_exclusive_blake3_hasher(a);
  blake3_hasher_update(lean_get_external_data(a), lean_sarray_cptr(input), input_len);
  return a;
}
