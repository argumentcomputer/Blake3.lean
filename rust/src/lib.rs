use std::sync::LazyLock;

use lean_ffi::include;
use lean_ffi::object::{ExternalClass, LeanByteArray, LeanExternal, LeanObject, LeanString};

static HASHER_CLASS: LazyLock<ExternalClass> =
    LazyLock::new(ExternalClass::register_with_drop::<blake3::Hasher>);

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_version() -> LeanString {
    LeanString::new("1.8.3")
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_init() -> LeanObject {
    LeanExternal::alloc(&HASHER_CLASS, blake3::Hasher::new()).into()
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_init_keyed(key: LeanByteArray) -> LeanObject {
    let bytes = key.as_bytes();
    let key_array: &[u8; 32] = bytes.try_into().expect("key must be 32 bytes");
    LeanExternal::alloc(&HASHER_CLASS, blake3::Hasher::new_keyed(key_array)).into()
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_init_derive_key(context: LeanByteArray) -> LeanObject {
    let bytes = context.as_bytes();
    let ctx_str = std::str::from_utf8(bytes).expect("context must be valid UTF-8");
    LeanExternal::alloc(&HASHER_CLASS, blake3::Hasher::new_derive_key(ctx_str)).into()
}

/// Ensure copy-on-write: if the object is shared, clone the hasher into a new
/// external object; otherwise return it as-is for in-place mutation.
unsafe fn ensure_exclusive(obj: LeanObject) -> LeanObject {
    if unsafe { include::lean_is_exclusive(obj.as_ptr() as *mut _) } {
        obj
    } else {
        let ext = unsafe { LeanExternal::<blake3::Hasher>::from_raw(obj.as_ptr()) };
        let cloned = ext.get().clone();
        obj.dec_ref();
        LeanExternal::alloc(&HASHER_CLASS, cloned).into()
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_hasher_update(
    self_: LeanObject,
    input: LeanByteArray,
) -> LeanObject {
    let obj = unsafe { ensure_exclusive(self_) };
    let hasher_ptr =
        unsafe { include::lean_get_external_data(obj.as_ptr() as *mut _) as *mut blake3::Hasher };
    unsafe { (*hasher_ptr).update(input.as_bytes()) };
    obj
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_hasher_finalize(self_: LeanObject, len: usize) -> LeanObject {
    let ext = unsafe { LeanExternal::<blake3::Hasher>::from_raw(self_.as_ptr()) };
    let hasher = ext.get();
    let out = LeanByteArray::alloc(len);
    let buf = unsafe {
        let cptr = include::lean_sarray_cptr(out.as_ptr() as *mut _);
        std::slice::from_raw_parts_mut(cptr, len)
    };
    hasher.finalize_xof().fill(buf);
    self_.dec_ref();
    out.into()
}
