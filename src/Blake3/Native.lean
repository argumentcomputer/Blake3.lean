import Blake3

namespace Blake3
/- @[extern "lean_blake3_initialize"] -/
constant HasherPointed : PointedType
def Hasher : Type := HasherPointed.type
instance : Inhabited Hasher := ⟨HasherPointed.val⟩

/-
Perform an unsafe IO operation for use in a pure context.
-/
unsafe def unsafeIO' [Inhabited α] (k : IO α) : α :=
  match unsafeIO k with
  | Except.ok a => a
  | Except.error e => panic e.toString

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


/- @[extern "blake3_hasher_init_keyed"] -/
/- constant initHasherKeyed (key: Array UInt8) : Hasher -/


/- @[extern "blake3_hasher_init_derive_key"] -/
/- constant initHasherDeriveKey (context: String) : Hasher -/

/- @[extern "blake3_hasher_init_derive_key_raw"] -/
/- constant initHasherDeriveKeyRaw (context: String) (contextLength : USize) : Hasher -/


/-
Put more data into the hasher. This can be called several times.
-/
/- @[implementedBy hasherUpdateImpl] -/
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
/- @[extern "blake3_hasher_finalize_seek"] -/
/- constant hasherFinalizeSeek : (hasher : Hasher) → (seek : UInt64) → (length : USize) → ByteArray -/

/-
Hash a ByteArray
-/
def hash (input : ByteArray) : Blake3Hash :=
  let hasher := initHasher ()
  let hasher := hasherUpdate hasher input (USize.ofNat input.size)
  let output := hasherFinalize hasher (USize.ofNat BLAKE3_OUT_LEN)
  if h : output.size = BLAKE3_OUT_LEN then
    ⟨output, h⟩
  else
    panic! "Incorrect output size"
