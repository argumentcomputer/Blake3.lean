/-
 Bindings to the Blake3 hashing library.
-/
namespace Blake3

constant BLAKE3_KEY_LEN: UInt16 := 32
constant BLAKE3_OUT_LEN: UInt16 := 32
constant BLAKE3_BLOCK_LEN: UInt16 := 64
constant BLAKE3_CHUNK_LEN: UInt16 := 1024
constant BLAKE3_MAX_DEPTH: UInt16 := 54


@[extern "blake3_hasher"]
constant Blake3Hasher : Type := Unit

/-
Version of the linked BLAKE3 implementation library.
-/
@[extern "blake3_version"]
constant internalVersion : Unit → String

constant version : String := internalVersion Unit.unit

/-
Initialize a hasher.
-/
@[extern "blake3_hasher_init"]
constant initHasher : IO Blake3Hasher

@[extern "blake3_hasher_init_keyed"]
constant initHasherKeyed (key: Array UInt8) : IO Blake3Hasher


@[extern "blake3_hasher_init_derive_key"]
constant initHasherDeriveKey (context: String) : IO Blake3Hasher

@[extern "blake3_hasher_init_derive_key_raw"]
constant initHasherDeriveKeyRaw (context: String) (contextLength : USize) : IO Blake3Hasher

/-
Put more data into the hasher. This can be called several times.
-/
@[extern "blake3_hasher_update"]
constant hasherUpdate : (input : ByteArray) → (length : USize) → IO Blake3Hasher

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "blake3_hasher_finalize"]
constant hasherFinalize : (output : ByteArray) → (length : USize) → IO Blake3Hasher

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "blake3_hasher_finalize_seek"]
constant hasherFinalizeSeek : (seek : UInt64) → (output : ByteArray) → (length : USize) → IO Blake3Hasher
