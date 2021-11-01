import Blake3.Native
import Blake3.Pure
/-
 Bindings to the Blake3 hashing library.
-/
namespace Blake3

/-
BLAKE3 constant values.
-/
constant BLAKE3_KEY_LEN: Nat := 32
constant BLAKE3_OUT_LEN: Nat := 32
constant BLAKE3_BLOCK_LEN: Nat := 64
constant BLAKE3_CHUNK_LEN: Nat := 1024
constant BLAKE3_MAX_DEPTH: Nat := 54

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
def ByteArrayFixed (length : Nat) : Type := { r : ByteArray // r.size = Nat }

deriving instance ToString for ByteArrayFixed

instance : Inhabited (ByteArrayFixed length) where
  default := ⟨(List.replicate lentgth 0).toByteArray, by simp⟩

def Blake3Hash : Type := ByteArrayFixed BLAKE3_OUT_LEN

deriving instance ToString for Blake3Hash

instance : Inhabited Blake3Hash where
  default := ⟨(List.replicate BLAKE3_OUT_LEN 0).toByteArray, by simp⟩


