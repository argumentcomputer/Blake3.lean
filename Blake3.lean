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
opaque initKeyed (key : @& ByteArray) : Hasher

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
def hashKeyed (input : @& ByteArray) (key : @& ByteArray) : Blake3Hash :=
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

namespace StatefulHashObject
  -- TODO: Can we avoid gaving explicit 'hash' field that includes key in the beginning
  structure Sponge where
    hasher: Hasher
    hash : ByteArray

  -- TODO: We have to enforce label to contain: 1) software identifier, 2) timestamp, 3) intended use-case 4) version
  -- This probably can be implemented using some RegExp
  -- Good label example: 'ix 2025-01-01 16:18:03 content-addressing v1'
  def checkLabel (label : String) : String := label

  def Sponge.new (checkLabel: String → String) (label : String) : Sponge := {
    hasher := Hasher.initDeriveKey (String.toUTF8 (checkLabel label))
    hash := ⟨#[]⟩
  }

  -- TODO: Ideally we should have automatic re-keying of the hasher, based on some counter
  -- (like in Rust reference: https://github.com/storojs72/BLAKE3/blob/sho/reference_impl/reference_impl.rs#L467)
  def Sponge.absorb (sponge: Sponge) (input: ByteArray) : Sponge := {
    sponge with hasher := sponge.hasher.update input
  }

  def Sponge.squeeze (sponge: Sponge) (length: Nat) : Sponge := {
    hasher := sponge.hasher
    hash := sponge.hasher.finalize (USize.ofNat (length + 2 * BLAKE3_KEY_LEN))
  }

  def extract_output (sponge: Sponge) : ByteArray := ByteArray.extract sponge.hash (2 * BLAKE3_KEY_LEN) (sponge.hash.size + 2 * BLAKE3_KEY_LEN)
  def extract_key (hash: ByteArray) : ByteArray := ByteArray.extract hash 0 BLAKE3_KEY_LEN

  -- This has to be "periodically" invoked manually for security reasons
  def Sponge.ratchet (extract_key : ByteArray → ByteArray) (sponge: Sponge): Sponge := {
    hasher := Hasher.initKeyed (extract_key sponge.hash)
    hash := ⟨#[]⟩
  }

end StatefulHashObject

end Blake3
