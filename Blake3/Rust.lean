module
public import Blake3
/-! Rust-backed BLAKE3 bindings. -/

namespace Blake3.Rust
open Blake3
public section

private opaque HasherNonempty : NonemptyType

def Hasher : Type := HasherNonempty.type

instance : Nonempty Hasher := HasherNonempty.property

@[extern "rs_blake3_version"]
protected opaque internalVersion : Unit → String

/-- Version of the linked Rust BLAKE3 implementation library. -/
def version : String := Blake3.Rust.internalVersion ()

@[extern "rs_blake3_init"]
opaque hasherInit : Unit → Hasher

@[extern "rs_blake3_init_keyed"]
opaque hasherInitKeyed : @& Blake3Key → Hasher

@[extern "rs_blake3_init_derive_key"]
opaque hasherInitDeriveKey : @& ByteArray → Hasher

@[extern "rs_blake3_hasher_update"]
opaque hasherUpdate : Hasher → @& ByteArray → Hasher

@[extern "rs_blake3_hasher_finalize"]
opaque hasherFinalize : Hasher → (length : USize) →
  { r : ByteArray // r.size = length.toNat }

instance : HasherOps Hasher where
  init := hasherInit
  initKeyed := hasherInitKeyed
  initDeriveKey := hasherInitDeriveKey
  update := hasherUpdate
  finalize := hasherFinalize

abbrev hash := HasherOps.hash (H := Hasher)
abbrev hashKeyed := HasherOps.hashKeyed (H := Hasher)
abbrev hashDeriveKey := HasherOps.hashDeriveKey (H := Hasher)
abbrev Sponge := Blake3.Sponge Hasher

-- Dot-notation aliases: `Hasher.init`, `h.update`, `h.finalizeWithLength`
namespace Hasher

abbrev init := hasherInit
abbrev update := hasherUpdate

def finalizeWithLength (hasher : Hasher) (length : Nat)
    (h : length < 2 ^ System.Platform.numBits := by native_decide) :=
  HasherOps.finalizeWithLength hasher length h

end Hasher

end
end Blake3.Rust
