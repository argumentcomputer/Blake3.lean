/-
 Bindings to the Blake3 hashing library.
-/
namespace Blake3

constant BLAKE3_KEY_LEN: Nat := 32
constant BLAKE3_OUT_LEN: Nat := 32
constant BLAKE3_BLOCK_LEN: Nat := 64
constant BLAKE3_CHUNK_LEN: Nat := 1024
constant BLAKE3_MAX_DEPTH: Nat := 54

universe u

/-
Simplification rules for ensuring type safety of Blake3Hash
-/
@[simp] theorem ByteArray.size_empty : ByteArray.empty.size = 0 :=
rfl

@[simp] theorem ByteArray.size_push (B : ByteArray) (a : UInt8) : (B.push a).size = B.size + 1 :=
by { cases B; simp only [ByteArray.push, ByteArray.size, Array.size_push] }

@[simp] theorem List.to_ByteArray_size : (L : List UInt8) → L.toByteArray.size = L.length
| [] => rfl
| a::l => by simp [List.toByteArray, to_ByteArray_loop_size]
where to_ByteArray_loop_size :
  (L : List UInt8) → (B : ByteArray) → (List.toByteArray.loop L B).size = L.length + B.size
| [], B => by simp [List.toByteArray.loop]
| a::l, B => by
    simp [List.toByteArray.loop, to_ByteArray_loop_size]
    rw [Nat.add_succ, Nat.succ_add]
/-
A dependent ByteArray which guarantees the correct byte length.
-/
def Blake3Hash : Type := { r : ByteArray // r.size = BLAKE3_OUT_LEN }
instance : Inhabited Blake3Hash where
  default := ⟨(List.replicate BLAKE3_OUT_LEN 0).toByteArray, by simp⟩

@[extern "blake3_hasher"]
constant HasherPointed : PointedType
def Hasher : Type := HasherPointed.type
instance : Inhabited Hasher := ⟨HasherPointed.val⟩

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
constant initHasher : Hasher

@[extern "blake3_hasher_init_keyed"]
constant initHasherKeyed (key: Array UInt8) : Hasher


@[extern "blake3_hasher_init_derive_key"]
constant initHasherDeriveKey (context: String) : Hasher

@[extern "blake3_hasher_init_derive_key_raw"]
constant initHasherDeriveKeyRaw (context: String) (contextLength : USize) : Hasher

/-
Put more data into the hasher. This can be called several times.
-/
@[extern "blake3_hasher_update"]
constant hasherUpdate : (hasher : Hasher) → (input : ByteArray) → (length : USize) → Hasher

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "blake3_hasher_finalize"]
constant hasherFinalize : (hasher : Hasher) → (length : USize) → ByteArray

/-
Finalize the hasher and write the output to an initialized array.
-/
@[extern "blake3_hasher_finalize_seek"]
constant hasherFinalizeSeek : (hasher : Hasher) → (seek : UInt64) → (length : USize) → ByteArray

/-
Hash a ByteArray
-/
def hash (input : ByteArray) : Blake3Hash :=
  let hasher := initHasher
  let hasher := hasherUpdate hasher input (USize.ofNat input.size)
  let output := hasherFinalize hasher (USize.ofNat BLAKE3_OUT_LEN)
  if h : output.size = BLAKE3_OUT_LEN then
    output
  else 
    panic "Incorrect output size"
