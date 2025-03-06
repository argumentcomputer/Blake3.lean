/-! Bindings to the BLAKE3 hashing library. -/

namespace Blake3

/-- BLAKE3 constants -/
abbrev BLAKE3_OUT_LEN : Nat := 32
abbrev BLAKE3_KEY_LEN : Nat := 32

/-- A wrapper around `ByteArray` whose size is `BLAKE3_OUT_LEN` -/
def Blake3Hash : Type := { r : ByteArray // r.size = BLAKE3_OUT_LEN }

/-- A wrapper around `ByteArray` whose size is `BLAKE3_KEY_LEN` -/
def Blake3Key : Type := { r : ByteArray // r.size = BLAKE3_KEY_LEN }

def Blake3Key.ofBytes (bytes : ByteArray)
    (h : bytes.size = BLAKE3_KEY_LEN := by rw [ByteArray.size]; rfl) : Blake3Key :=
  ⟨bytes, h⟩

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
opaque initKeyed (key : @& Blake3Key) : Hasher

@[extern "lean_blake3_init_derive_key"]
opaque initDeriveKey (context : @& ByteArray) : Hasher

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
def hashKeyed (input : @& ByteArray) (key : @& Blake3Key) : Blake3Hash :=
  let hasher := Hasher.initKeyed key
  let hasher := hasher.update input
  let output := hasher.finalize BLAKE3_OUT_LEN.toUSize
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"

/-- Hash a ByteArray using initializer parameterized by some context -/
def hashDeriveKey (input context : @& ByteArray) : Blake3Hash :=
  let hasher := Hasher.initDeriveKey context
  let hasher := hasher.update input
  let output := hasher.finalize BLAKE3_OUT_LEN.toUSize
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"

end Blake3
