/-
Copyright (c) 2026 Argument Computer Corporation.
SPDX-License-Identifier: MIT OR Apache-2.0
-/

import Lean
import Blake3.Pure.Proofs

open Lean Lean.Elab Command

namespace Blake3.PureAudit

private def roots : Array (Name × Array Name) := #[
  (`Blake3.Pure.leftLen_positive, #[]),
  (`Blake3.Pure.leftLen_lt, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.encodeLittleEndian_length, #[``propext]),
  (`Blake3.Pure.littleEndian_bound, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.littleEndian_encode, #[``propext]),
  (`Blake3.Pure.schedules_permute, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.schedules_next, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.rotateRight_bits, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.bytesWord_value, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.wordBytes_encoding, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.bytesWord_wordBytes, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.bytesWord_pack, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.wordBytes_pack, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.wordBytes_bytesWord, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.bytesWord_injective, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.blockWords_byte, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.blockWords_value, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.cvBytes_value, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.g_unchanged, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.g_values, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.initialWords_counter, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.parentOutput_values, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.leftLen_bounds, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.leftLen_chunks, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.leftLen_chunk_multiple, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.leftLen_unique, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.chunkLoop_small, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.chunkLoop_step, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.chunkLoop_counter, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.chunkOutput_counter, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.chunkLoop_reads, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.ChunkReads.complete, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.chunkLoop_iff, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.ChunkReads.framing, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.chunkOutput_framing, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.subtree_small, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.subtree_step, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.subtree_root_counter, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.subtree_tree, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.TreeHash.complete, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.subtree_iff, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.TreeHash.unique, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.native_counter, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.native_child_spans, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.ChunkAt.native, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.digest_native_counters, #[``propext, ``Classical.choice, ``Quot.sound]),
  (`Blake3.Pure.digest_tree, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.hash_size, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.hash_digest, #[``propext, ``Quot.sound]),
  (`Blake3.Pure.hash_tree, #[``propext, ``Quot.sound])]

private def constants (info : Lean.ConstantInfo) : Array Lean.Name :=
  info.type.getUsedConstants ++ match info with
  | .thmInfo value => value.value.getUsedConstants
  | .defnInfo value => value.value.getUsedConstants
  | .opaqueInfo value => value.value.getUsedConstants
  | .inductInfo value => value.ctors.toArray
  | _ => #[]

private partial def closure (env : Lean.Environment) (runtime : Bool) (pending : List Lean.Name)
    (seen : NameSet := {}) : NameSet :=
  match pending with
  | [] => seen
  | name :: rest =>
    if seen.contains name then closure env runtime rest seen
    else match env.checked.get.find? name with
    | none => closure env runtime rest (seen.insert name)
    | some info =>
      let extras := if runtime then Id.run do
        let mut names := #[]
        let worker := Lean.Compiler.mkUnsafeRecName name
        if (env.checked.get.find? worker).isSome then names := names.push worker
        if let some other := Lean.Compiler.getImplementedBy? env name then
          names := names.push other
        if let some other := (Lean.Compiler.CSimp.ext.getState env).map.find? name then
          names := names.push other.toDeclName
        return names
      else #[]
      closure env runtime ((constants info ++ extras).toList ++ rest) (seen.insert name)

private def projectConstant (env : Lean.Environment) (name : Lean.Name) : Bool :=
  match env.getModuleIdxFor? name with
  | none => false
  | some idx => (`Blake3).isPrefixOf env.allImportedModuleNames[idx.toNat]!

private def sortedNames (names : Array Name) : Array Name := names.qsort Name.lt

/-- Read checked types, bodies and constructors; imported cached axiom
summaries can omit constructor dependencies. -/
private def checkAxioms (env : Environment) (root : Name) (expected : Array Name) :
    CommandElabM (Array Name) := do
  let reachable := closure env false [root]
  let mut actual := #[]
  for name in reachable do
    let some info := env.checked.get.find? name
      | throwError "BLAKE3 audit: unavailable checked dependency: {name}"
    if info.isAxiom then actual := actual.push name
  let sorted := sortedNames actual
  unless sorted == sortedNames expected do
    throwError "BLAKE3 axiom boundary changed for {root}: expected {sortedNames expected}, actual {sorted}"
  return sorted

-- Constructor closure and exact-set failure paths are part of the audit.
private inductive ConstructorAuditFixture where
  | plain
  | withProof (proof : propext (Iff.refl True) = rfl)

run_cmd do
  let _ ← checkAxioms (← getEnv) ``ConstructorAuditFixture.plain #[``propext]
  let _ ← checkAxioms (← getEnv) ``Eq.refl #[]

/-- error: BLAKE3 axiom boundary changed for Eq.refl: expected [propext], actual [] -/
#guard_msgs in
run_cmd do
  let _ ← checkAxioms (← getEnv) ``Eq.refl #[``propext]

/-- error: BLAKE3 axiom boundary changed for propext: expected [], actual [propext] -/
#guard_msgs in
run_cmd do
  let _ ← checkAxioms (← getEnv) ``propext #[]

run_cmd do
  let env ← getEnv
  for (root, expected) in roots do
    let _ ← checkAxioms env root expected
  let mut workers := #[]
  for name in closure env true (roots.toList.map Prod.fst) do
    let some info := env.checked.get.find? name | throwError "Unavailable runtime dependency: {name}"
    if projectConstant env name then
      if Lean.isExtern env name then throwError "Unexpected BLAKE3 FFI dependency: {name}"
      if (Lean.Compiler.getImplementedBy? env name).isSome ||
          ((Lean.Compiler.CSimp.ext.getState env).map.find? name).isSome then
        throwError "Unexpected BLAKE3 implementation replacement: {name}"
      if let some parent := Lean.Compiler.isUnsafeRecName? name then
        let some (.defnInfo source) := env.checked.get.find? parent | throwError "Missing recursion source: {name}"
        unless source.safety == .safe do throwError "Unsafe recursion source: {parent}"
        workers := workers.push name
      else match info with
        | .defnInfo value => unless value.safety == .safe do throwError "Unsafe BLAKE3 definition: {name}"
        | .opaqueInfo _ => throwError "Opaque BLAKE3 implementation: {name}"
        | _ => pure ()
  unless workers.qsort Name.lt == #[`Blake3.Pure.chunkLoop._unsafe_rec,
      `Blake3.Pure.encodeLittleEndian._unsafe_rec, `Blake3.Pure.subtree._unsafe_rec] do
    throwError "BLAKE3 recursion inventory changed: {workers}"
  logInfo "Pure BLAKE3 audit: 50 exact axiom sets, 3 safe recursion sources, no BLAKE3 FFI or opaque implementations"

end Blake3.PureAudit
