/-! Bindings to the BLAKE3 hashing library. -/

namespace Blake3

/-- BLAKE3 output length -/
abbrev BLAKE3_OUT_LEN : Nat := 32

/-- A dependent ByteArray which guarantees the correct byte length. -/
def Blake3Hash : Type := { r : ByteArray // r.size = BLAKE3_OUT_LEN }

instance : Inhabited Blake3Hash where
  default := ⟨⟨#[
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0
  ]⟩, by rw [ByteArray.size]; rfl⟩

private opaque HasherNonempty : NonemptyType

def Hasher : Type := HasherNonempty.type

instance : Nonempty Hasher := HasherNonempty.property

@[extern "lean_blake3_version"]
protected opaque internalVersion : Unit → String

/-- Version of the linked BLAKE3 implementation library. -/
def version : String := Blake3.internalVersion ()

namespace Hasher

/-- Initialize a hasher. -/
@[extern "lean_blake3_init"]
opaque init : Unit → Hasher

/-- Initialize a hasher using pseudo-random key -/
@[extern "lean_blake3_init_keyed"]
opaque init_keyed (key : @& ByteArray) : Hasher

@[extern "lean_blake3_init_derive_key"]
opaque init_derive_key (context : @& ByteArray) : Hasher

/-- Put more data into the hasher. This can be called several times. -/
@[extern "lean_blake3_hasher_update"]
opaque update (hasher : Hasher) (input : @& ByteArray) : Hasher

/-- Finalize the hasher and write the output to an array of a given length. -/
@[extern "lean_blake3_hasher_finalize"]
opaque finalize : (hasher : Hasher) → (length : USize) → ByteArray

end Hasher

/-- Hash a ByteArray -/
def hash (input : ByteArray) : Blake3Hash :=
  let hasher := Hasher.init ()
  let hasher := hasher.update input
  let output := hasher.finalize BLAKE3_OUT_LEN.toUSize
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"

/-- Hash a ByteArray using keyed initializer -/
def hash_keyed (input key : ByteArray) : Blake3Hash :=
  let hasher := Hasher.init_keyed key
  let hasher := hasher.update input
  let output := hasher.finalize BLAKE3_OUT_LEN.toUSize
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"

/-- Hash a ByteArray using initializer parameterized by some context -/
def hash_derive_key (input context : ByteArray) : Blake3Hash :=
  let hasher := Hasher.init_derive_key context
  let hasher := hasher.update input
  let output := hasher.finalize BLAKE3_OUT_LEN.toUSize
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"

end Blake3
