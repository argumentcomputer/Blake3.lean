module
public import Blake3
/-! C-backed BLAKE3 bindings. -/

namespace Blake3.C
open Blake3
public section

private opaque HasherNonempty : NonemptyType

def Hasher : Type := HasherNonempty.type

instance : Nonempty Hasher := HasherNonempty.property

@[extern "c_blake3_version"]
protected opaque internalVersion : Unit → String

/-- Version of the linked C BLAKE3 implementation library. -/
def version : String := Blake3.C.internalVersion ()

@[extern "c_blake3_init"]
opaque hasherInit : Unit → Hasher

@[extern "c_blake3_init_keyed"]
opaque hasherInitKeyed : @& Blake3Key → Hasher

@[extern "c_blake3_init_derive_key"]
opaque hasherInitDeriveKey : @& ByteArray → Hasher

@[extern "c_blake3_hasher_update"]
opaque hasherUpdate : Hasher → @& ByteArray → Hasher

@[extern "c_blake3_hasher_finalize"]
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

end
end Blake3.C
