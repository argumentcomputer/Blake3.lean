#include "blake3.h"
#include "lean/lean.h"

/**
 * Wrap around the blake3_version function and construct a lean string.
 */
lean_object *lean_blake3_version() {
  const char *v = blake3_version();
  lean_obj_res r = lean_mk_string(v);
  return r;
}

/**
 * Free the memory for this hasher. This makes all other references to this
 * address invalid.
 */
static inline void blake3_hasher_free(blake3_hasher *self) {
  // Mark memory as available
  free(self);
  self = NULL;
}

static void blake3_hasher_finalizer(void *ptr) { blake3_hasher_free(ptr); }

inline static void blake3_hasher_foreach(void *mod, b_lean_obj_arg fn) {}

static lean_external_class *g_blake3_hasher_class = NULL;

static lean_external_class *get_blake3_hasher_class() {
  if (g_blake3_hasher_class == NULL) {
    g_blake3_hasher_class = lean_register_external_class(
        &blake3_hasher_finalizer, &blake3_hasher_foreach);
  }
  return g_blake3_hasher_class;
}
/**
 * Copy the contents of the hasher to a new memory location.
 */
static inline lean_object *blake3_hasher_copy(lean_object *self) {
  assert(lean_get_external_class(self) == get_blake3_hasher_class());
  blake3_hasher *a = (blake3_hasher *)lean_get_external_data(self);
  blake3_hasher *copy = malloc(sizeof(blake3_hasher));
  *copy = *a;

  return lean_alloc_external(get_blake3_hasher_class(), copy);
}

extern void blake3_hasher_update(blake3_hasher *self, const void *input,
                                 size_t input_len);

/**
 * Initialize a hasher.
 */
lean_obj_res lean_blake3_initialize() {
  return lean_io_result_mk_ok(lean_box(0));
}

/**
 * Ensure the hasher is exclusive.
 */
static inline lean_obj_res lean_ensure_exclusive_blake3_hasher(lean_obj_arg a) {
  if (lean_is_exclusive(a))
    return a;
  return blake3_hasher_copy(a);
}

lean_obj_res lean_blake3_hasher_update(lean_obj_arg self, b_lean_obj_arg input,
                                       size_t input_len) {
  lean_object *a = lean_ensure_exclusive_blake3_hasher(self);
  blake3_hasher_update(lean_get_external_data(a), lean_sarray_cptr(input),
                       input_len);
  return a;
}
