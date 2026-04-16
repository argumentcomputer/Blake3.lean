use std::sync::LazyLock;

use lean_ffi::object::{
    ExternalClass, LeanBorrowed, LeanByteArray, LeanExternal, LeanOwned, LeanString,
};

static HASHER_CLASS: LazyLock<ExternalClass> =
    LazyLock::new(ExternalClass::register_with_drop::<blake3::Hasher>);

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_version() -> LeanString<LeanOwned> {
    LeanString::new("1.8.4")
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_init() -> LeanExternal<blake3::Hasher, LeanOwned> {
    LeanExternal::alloc(&HASHER_CLASS, blake3::Hasher::new())
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_init_keyed(
    key: LeanByteArray<LeanBorrowed<'_>>,
) -> LeanExternal<blake3::Hasher, LeanOwned> {
    let bytes = key.as_bytes();
    let key_array: &[u8; 32] = bytes.try_into().expect("key must be 32 bytes");
    LeanExternal::alloc(&HASHER_CLASS, blake3::Hasher::new_keyed(key_array))
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_init_derive_key(
    context: LeanByteArray<LeanBorrowed<'_>>,
) -> LeanExternal<blake3::Hasher, LeanOwned> {
    let bytes = context.as_bytes();
    let ctx_str = std::str::from_utf8(bytes).expect("context must be valid UTF-8");
    LeanExternal::alloc(&HASHER_CLASS, blake3::Hasher::new_derive_key(ctx_str))
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_hasher_update(
    mut hasher: LeanExternal<blake3::Hasher, LeanOwned>,
    input: LeanByteArray<LeanBorrowed<'_>>,
) -> LeanExternal<blake3::Hasher, LeanOwned> {
    if let Some(h) = hasher.get_mut() {
        h.update(input.as_bytes());
        hasher
    } else {
        let mut new_hasher = hasher.get().clone();
        new_hasher.update(input.as_bytes());
        LeanExternal::alloc(&HASHER_CLASS, new_hasher)
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_blake3_hasher_finalize(
    hasher: LeanExternal<blake3::Hasher, LeanOwned>,
    len: usize,
) -> LeanByteArray<LeanOwned> {
    let mut buf = vec![0u8; len];
    hasher.get().finalize_xof().fill(&mut buf);
    LeanByteArray::from_bytes(&buf)
}
