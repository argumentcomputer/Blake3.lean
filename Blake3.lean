/-! Bindings to the BLAKE3 hashing library. -/

namespace Blake3

/-- BLAKE3 output length -/
def BLAKE3_OUT_LEN : Nat := 32

/-- A dependent ByteArray which guarantees the correct byte length. -/
def Blake3Hash : Type := { r : ByteArray // r.size = BLAKE3_OUT_LEN }

instance : Inhabited Blake3Hash where
  default := ⟨⟨#[
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0
  ]⟩, by simp [ByteArray.size, BLAKE3_OUT_LEN]⟩

private opaque HasherNonempty : NonemptyType

def Hasher : Type := HasherNonempty.type

instance : Nonempty Hasher := HasherNonempty.property

/-- Version of the linked BLAKE3 implementation library. -/
@[extern "lean_blake3_version"]
protected opaque internalVersion : Unit → String

def version : String := Blake3.internalVersion ()

namespace Hasher

/-- Initialize a hasher. -/
@[extern "lean_blake3_initialize"]
opaque init : Unit → Hasher

/-- Put more data into the hasher. This can be called several times. -/
@[extern "lean_blake3_hasher_update"]
opaque update (hasher : Hasher) (input : ByteArray) (length : USize) : Hasher

/-- Finalize the hasher and write the output to an initialized array. -/
@[extern "lean_blake3_hasher_finalize"]
opaque finalize : (hasher : Hasher) → (length : USize) → ByteArray

end Hasher

/-- Hash a ByteArray -/
def hash (input : ByteArray) : Blake3Hash :=
  let hasher := Hasher.init ()
  let hasher := hasher.update input (USize.ofNat input.size)
  let output := hasher.finalize (USize.ofNat BLAKE3_OUT_LEN)
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"

end Blake3
