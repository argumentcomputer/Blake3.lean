/-
Bindings to the Blake3 hashing library.
-/
import BinaryTools

namespace Blake3

universe u
/-
BLAKE3 constant values.
-/
constant BLAKE3_KEY_LEN: Nat := 32
constant BLAKE3_OUT_LEN: Nat := 32
constant BLAKE3_BLOCK_LEN: Nat := 64
constant BLAKE3_CHUNK_LEN: Nat := 1024
constant BLAKE3_MAX_DEPTH: Nat := 54

/-
A dependent ByteArray which guarantees the correct byte length.
-/
def Blake3Hash : Type := { r : ByteArray // r.size = BLAKE3_OUT_LEN }

@[defaultInstance]
instance : Into ByteArray Blake3Hash := ⟨Subtype.val⟩

instance : Into String Blake3Hash := ⟨toBase64⟩

instance : ToString Blake3Hash := ⟨into⟩

instance : Inhabited Blake3Hash where
  default := ⟨(List.replicate BLAKE3_OUT_LEN 0).toByteArray, by simp⟩


constant HasherPointed : PointedType

def Hasher : Type := HasherPointed.type

instance : Inhabited Hasher := ⟨HasherPointed.val⟩


/-
Version of the linked BLAKE3 implementation library.
-/
@[extern "lean_blake3_version"]
constant internalVersion : Unit → String

constant version : String := internalVersion ()

/-
Initialize a hasher.
-/
@[extern "lean_blake3_initialize"]
constant initHasher : Unit → Hasher


@[extern "blake3_hasher_init_keyed"]
constant initHasherKeyed (key: Array UInt8) : Hasher


@[extern "blake3_hasher_init_derive_key"]
constant initHasherDeriveKey (context: String) : Hasher

@[extern "blake3_hasher_init_derive_key_raw"]
constant initHasherDeriveKeyRaw (context: String) (contextLength : USize) : Hasher


/-
Put more data into the hasher. This can be called several times.
-/
@[extern "lean_blake3_hasher_update"]
constant hasherUpdate (hasher : Hasher) (input : ByteArray) (length : USize) : Hasher

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "lean_blake3_hasher_finalize"]
constant hasherFinalize : (hasher : Hasher) → (length : USize) → ByteArray

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "blake3_hasher_finalize_seek"]
constant hasherFinalizeSeek : (hasher : Hasher) → (seek : UInt64) → (length : USize) → ByteArray

/-
Hash a ByteArray
-/
def hash {I: Type u} [Into ByteArray I] (input : I) : Blake3Hash :=
  let input : ByteArray := Into.into input
  let hasher := initHasher ()
  let hasher := hasherUpdate hasher input (USize.ofNat input.size)
  let output := hasherFinalize hasher (USize.ofNat BLAKE3_OUT_LEN)
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"
