/-
Bindings to the Blake3 hashing library.
-/
import Blake3.BinaryTools

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


private constant HasherNonempty : NonemptyType

def Hasher : Type := HasherNonempty.type

instance : Nonempty Hasher := HasherNonempty.property


/-
Version of the linked BLAKE3 implementation library.
-/
@[extern "lean_blake3_version"]
protected constant internalVersion : Unit → String

def version : String := Blake3.internalVersion ()

namespace Hasher
/-
Initialize a hasher.
-/
@[extern "lean_blake3_initialize"]
constant init : Unit → Hasher


@[extern "blake3_hasher_init_keyed"]
constant initKeyed (key: Array UInt8) : Hasher


@[extern "blake3_hasher_init_derive_key"]
constant initDeriveKey (context: String) : Hasher

@[extern "blake3_hasher_init_derive_key_raw"]
constant initDeriveKeyRaw (context: String) (contextLength : USize) : Hasher


/-
Put more data into the hasher. This can be called several times.
-/
@[extern "lean_blake3_hasher_update"]
constant update (hasher : Hasher) (input : ByteArray) (length : USize) : Hasher

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "lean_blake3_hasher_finalize"]
constant finalize : (hasher : Hasher) → (length : USize) → ByteArray

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "blake3_hasher_finalize_seek"]
constant finalizeSeek : (hasher : Hasher) → (seek : UInt64) → (length : USize) → ByteArray

end Hasher

/-
Hash a ByteArray
-/
def hash {I: Type u} [Into ByteArray I] (input : I) : Blake3Hash :=
  let input : ByteArray := Into.into input
  let hasher := Hasher.init ()
  let hasher := hasher.update input (USize.ofNat input.size)
  let output := hasher.finalize (USize.ofNat BLAKE3_OUT_LEN)
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"

end Blake3
