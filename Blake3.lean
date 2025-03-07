/-! Bindings to the BLAKE3 hashing library. -/

theorem ByteArray.size_of_extract {hash : ByteArray} (hbe : b ≤ e) (h : e ≤ hash.data.size) :
    (hash.extract b e).size = e - b := by
  simp [ByteArray.size, ByteArray.extract, ByteArray.copySlice, ByteArray.empty, ByteArray.mkEmpty]
  rw [Nat.add_comm, Nat.sub_add_cancel hbe, Nat.min_eq_left h]

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

instance {length : USize} : Inhabited { r : ByteArray // r.size = length.toNat } where
  default := ⟨
    ⟨⟨List.replicate length.toNat 0⟩⟩,
    by simp only [ByteArray.size, List.toArray_replicate, Array.size_mkArray]
  ⟩

/-- Finalize the hasher and write the output to an array of a given length. -/
@[extern "lean_blake3_hasher_finalize"]
opaque finalize : (hasher : Hasher) → (length : USize) →
  {r : ByteArray // r.size = length.toNat}

def finalizeWithLength (hasher : Hasher) (length : Nat)
    (h : length % 2 ^ System.Platform.numBits = length := by native_decide) :
    { r : ByteArray // r.size = length } :=
  let ⟨hash, h'⟩ := hasher.finalize length.toUSize
  have hash_size_eq_len : hash.size = length := by
    cases System.Platform.numBits_eq with
    | inl h32 => rw [h32] at h; simp [h', h32]; exact h
    | inr h64 => rw [h64] at h; simp [h', h64]; exact h
  ⟨hash, hash_size_eq_len⟩

end Hasher

/-- Hash a ByteArray -/
def hash (input : ByteArray) : Blake3Hash :=
  let hasher := Hasher.init ()
  let hasher := hasher.update input
  hasher.finalizeWithLength BLAKE3_OUT_LEN

/-- Hash a ByteArray using keyed initializer -/
def hashKeyed (input : @& ByteArray) (key : @& Blake3Key) : Blake3Hash :=
  let hasher := Hasher.initKeyed key
  let hasher := hasher.update input
  hasher.finalizeWithLength BLAKE3_OUT_LEN

/-- Hash a ByteArray using initializer parameterized by some context -/
def hashDeriveKey (input context : @& ByteArray) : Blake3Hash :=
  let hasher := Hasher.initDeriveKey context
  let hasher := hasher.update input
  hasher.finalizeWithLength BLAKE3_OUT_LEN

structure Sponge where
  hasher : Hasher
  counter : Nat

namespace Sponge

abbrev ABSORB_MAX_BYTES := UInt32.size - 1
abbrev DEFAULT_REKEYING_STAGE := UInt16.size - 1

def init (label : String) (_h : ¬label.isEmpty := by decide) : Sponge :=
  ⟨Hasher.initDeriveKey label.toUTF8, 0⟩

def ratchet (sponge : Sponge) : Sponge :=
  let key := sponge.hasher.finalizeWithLength BLAKE3_KEY_LEN
  { sponge with hasher := Hasher.initKeyed key }

def absorb (sponge : Sponge) (bytes : ByteArray)
    (_h : bytes.size < ABSORB_MAX_BYTES := by norm_cast) : Sponge :=
  let highCounter := sponge.counter >= DEFAULT_REKEYING_STAGE
  let sponge := if highCounter then sponge.ratchet else sponge
  -- Is `ratchet` supposed to reset `counter` to 0? Or should it be reset
  -- everytime `highCounter` is `true`?
  ⟨sponge.hasher.update bytes, sponge.counter + 1⟩

def squeeze (sponge : Sponge) (length : USize)
    (h_len_bound : 2 * BLAKE3_OUT_LEN + length.toNat < 2 ^ System.Platform.numBits :=
      by native_decide) :
    { r : ByteArray // r.size = length.toNat } :=
  let ⟨tmp, h⟩ := sponge.hasher.finalize (2 * BLAKE3_OUT_LEN.toUSize + length)
  let b := (2 * BLAKE3_OUT_LEN)
  let e := (2 * BLAKE3_OUT_LEN + length.toNat)
  let y := tmp.extract b e
  have sub_e_b_eq_length : e - b = length.toNat := by
    simp only [b, e]
    rw [Nat.add_comm _ length.toNat, Nat.add_sub_cancel]
  have le_b_e : b ≤ e := by simp only [Nat.le_add_right, e, b]
  have h_e_bound : e ≤ tmp.size := by
    simp [e, h]
    cases System.Platform.numBits_eq with
    | inl h32 =>
      have hbound : (2 * BLAKE3_OUT_LEN) + length.toNat < 2 ^ 32 := by
        rwa [h32, Nat.pow_succ] at h_len_bound
      rw [h32, BLAKE3_OUT_LEN]
      simp only [Nat.mod_eq_of_lt hbound, Nat.le_refl]
    | inr h64 =>
      have hbound : (2 * BLAKE3_OUT_LEN) + length.toNat < 2 ^ 64 := by
        rwa [h64, Nat.pow_succ] at h_len_bound
      rw [h64, BLAKE3_OUT_LEN]
      simp only [Nat.mod_eq_of_lt hbound, Nat.le_refl]
  have size_of_extract := ByteArray.size_of_extract le_b_e h_e_bound
  ⟨y, by simp only [y, size_of_extract, sub_e_b_eq_length]⟩

end Sponge

end Blake3
