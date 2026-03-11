module
/-! Shared types and generic logic for BLAKE3 bindings. -/

private theorem ByteArray.size_of_extract {hash : ByteArray} (h : e ≤ hash.size) :
    (hash.extract b e).size = e - b := by
  simp [Nat.min_eq_left h]

namespace Blake3
public section

/-- BLAKE3 constants -/
abbrev BLAKE3_OUT_LEN : Nat := 32
abbrev BLAKE3_KEY_LEN : Nat := 32

/-- A wrapper around `ByteArray` whose size is `BLAKE3_OUT_LEN` -/
@[expose]
def Blake3Hash : Type := { r : ByteArray // r.size = BLAKE3_OUT_LEN }

/-- A wrapper around `ByteArray` whose size is `BLAKE3_KEY_LEN` -/
@[expose]
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

/-- Typeclass for BLAKE3 hasher backends (C, Rust, etc.). -/
class HasherOps (H : Type) where
  init : Unit → H
  initKeyed : Blake3Key → H
  initDeriveKey : ByteArray → H
  update : H → ByteArray → H
  finalize : H → (length : USize) → { r : ByteArray // r.size = length.toNat }

instance {length : USize} : Inhabited { r : ByteArray // r.size = length.toNat } where
  default := ⟨
    ⟨⟨List.replicate length.toNat 0⟩⟩,
    by simp only [ByteArray.size, List.toArray_replicate, Array.size_replicate]
  ⟩

namespace HasherOps

variable {H : Type} [HasherOps H]

def finalizeWithLength (hasher : H) (length : Nat)
    (h : length < 2 ^ System.Platform.numBits := by native_decide) :
    { r : ByteArray // r.size = length } :=
  let ⟨hash, h'⟩ := HasherOps.finalize hasher length.toUSize
  have hash_size_eq_len : hash.size = length := by
    cases System.Platform.numBits_eq with
    | inl h32 => rw [h32] at h; simp [h', h32]; exact h
    | inr h64 => rw [h64] at h; simp [h', h64]; exact h
  ⟨hash, hash_size_eq_len⟩

/-- Hash a ByteArray -/
def hash (input : ByteArray) : Blake3Hash :=
  let hasher := HasherOps.init (H := H) ()
  let hasher := HasherOps.update hasher input
  finalizeWithLength hasher BLAKE3_OUT_LEN

/-- Hash a ByteArray using keyed initializer -/
def hashKeyed (input : ByteArray) (key : Blake3Key) : Blake3Hash :=
  let hasher := HasherOps.initKeyed (H := H) key
  let hasher := HasherOps.update hasher input
  finalizeWithLength hasher BLAKE3_OUT_LEN

/-- Hash a ByteArray using initializer parameterized by some context -/
def hashDeriveKey (input context : ByteArray) : Blake3Hash :=
  let hasher := HasherOps.initDeriveKey (H := H) context
  let hasher := HasherOps.update hasher input
  finalizeWithLength hasher BLAKE3_OUT_LEN

end HasherOps

/-- Generic sponge construction over any BLAKE3 hasher backend. -/
structure Sponge (H : Type) where
  hasher : H
  counter : Nat

namespace Sponge

abbrev ABSORB_MAX_BYTES := UInt32.size - 1
abbrev DEFAULT_REKEYING_STAGE := UInt16.size - 1

variable {H : Type} [HasherOps H]

def init (label : String) (_h : ¬label.isEmpty := by native_decide) : Sponge H :=
  ⟨HasherOps.initDeriveKey label.toUTF8, 0⟩

def ratchet (sponge : Sponge H) : Sponge H :=
  let key := HasherOps.finalizeWithLength sponge.hasher BLAKE3_KEY_LEN
  { sponge with hasher := HasherOps.initKeyed key, counter := 0 }

def absorb (sponge : Sponge H) (bytes : ByteArray)
    (_h : bytes.size < ABSORB_MAX_BYTES := by norm_cast) : Sponge H :=
  let highCounter := sponge.counter >= DEFAULT_REKEYING_STAGE
  let sponge := if highCounter then sponge.ratchet else sponge
  ⟨HasherOps.update sponge.hasher bytes, sponge.counter + 1⟩

def squeeze (sponge : Sponge H) (length : USize)
    (h_len_bound : 2 * BLAKE3_OUT_LEN + length.toNat < 2 ^ System.Platform.numBits :=
      by native_decide) :
    { r : ByteArray // r.size = length.toNat } :=
  let ⟨tmp, h⟩ := HasherOps.finalize sponge.hasher (2 * BLAKE3_OUT_LEN.toUSize + length)
  let b := (2 * BLAKE3_OUT_LEN)
  let e := (2 * BLAKE3_OUT_LEN + length.toNat)
  let y := tmp.extract b e
  have sub_e_b_eq_length : e - b = length.toNat := by
    simp only [b, e]
    rw [Nat.add_comm _ length.toNat, Nat.add_sub_cancel]
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
  have size_of_extract := ByteArray.size_of_extract h_e_bound
  ⟨y, by rw [size_of_extract, sub_e_b_eq_length]⟩

end Sponge

end
end Blake3
