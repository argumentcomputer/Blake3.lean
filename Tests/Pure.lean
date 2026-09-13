/-
Copyright (c) 2026 Argument Computer Corporation.
SPDX-License-Identifier: MIT OR Apache-2.0
-/

import Blake3.Pure.Proofs
import Blake3.C
import Blake3.Rust
import Tests.PureAudit
import Tests.PureVectors

namespace Blake3.PureTests

private def testInput (length salt : Nat) : ByteArray :=
  ⟨Array.ofFn fun index : Fin length => ((index.val * 17 + index.val / 251 * 13 + salt * 29) % 256).toUInt8⟩

private def lengths : List Nat :=
  ((List.range 129) ++ (List.range 65).map (960 + ·) ++ [255, 256, 257, 511, 512, 513] ++
    (((List.range 17).map (· + 1) ++ [32, 64, 128]).flatMap fun chunks =>
      [chunks * 1024 - 1, chunks * 1024, chunks * 1024 + 1])).eraseDups

private def knownAnswer (input : ByteArray) (expected : List UInt8) : IO Unit := do
  unless (Pure.hash input).val.data.toList == expected do
    throw (IO.userError "pure Blake3 known-answer test failed")

def run (compareC compareRust : Bool) : IO Unit := do
  -- First 32 output bytes from the BLAKE3 team's standard unkeyed vectors.
  knownAnswer ByteArray.empty [
    0xaf, 0x13, 0x49, 0xb9, 0xf5, 0xf9, 0xa1, 0xa6,
    0xa0, 0x40, 0x4d, 0xea, 0x36, 0xdc, 0xc9, 0x49,
    0x9b, 0xcb, 0x25, 0xc9, 0xad, 0xc1, 0x12, 0xb7,
    0xcc, 0x9a, 0x93, 0xca, 0xe4, 0x1f, 0x32, 0x62]
  knownAnswer ⟨#[0]⟩ [
    0x2d, 0x3a, 0xde, 0xdf, 0xf1, 0x1b, 0x61, 0xf1,
    0x4c, 0x88, 0x6e, 0x35, 0xaf, 0xa0, 0x36, 0x73,
    0x6d, 0xcd, 0x87, 0xa7, 0x4d, 0x27, 0xb5, 0xc1,
    0x51, 0x02, 0x25, 0xd0, 0xf5, 0x92, 0xe2, 0x13]
  unless lengths.length == 258 do throw (IO.userError "incomplete pure Blake3 boundary cases")
  let mut trees := 0
  for (length, salt) in lengths.zipIdx do
    let input := testInput length salt
    let actual := (Pure.hash input).val
    if compareC then
      unless actual == (C.hash input).val do throw (IO.userError s!"pure/C Blake3 differs at {length} bytes")
    if compareRust then
      unless actual == (Rust.hash input).val do throw (IO.userError s!"pure/Rust Blake3 differs at {length} bytes")
    if length > 1024 then
      trees := trees + 1
      let split := Pure.leftLen length
      let left := Pure.subtree 0 (input.data.toList.take split)
      let right := Pure.subtree (split / 1024) (input.data.toList.drop split)
      let parent := Pure.parentOutput left.chainingValue right.chainingValue
      unless parent.rootHash.toList == actual.data.toList do throw (IO.userError "pure Blake3 subtree composition differs")
  unless trees == 58 do throw (IO.userError "incomplete pure Blake3 tree cases")
  unless chunkVectors.length == 42 && parentVectors.length == 64 do
    throw (IO.userError "incomplete native component vectors")
  for (counter, length, expected) in chunkVectors do
    let input := testInput length (counter % 251)
    let actual := Pure.cvBytes (Pure.chunkOutput counter.toUInt64 input.data.toList).chainingValue
    unless actual.toList == expected do throw (IO.userError s!"pure Blake3 chunk differs at {counter}, {length}")
  for ((expectedCV, expectedRoot, expectedOrdinary), salt) in parentVectors.zipIdx do
    let left := testInput 32 salt
    let right := testInput 32 (salt + 83)
    let cv := fun bytes : ByteArray => Vector.ofFn fun word : Fin 8 =>
      Pure.bytesWord (Vector.ofFn fun byte : Fin 4 => bytes[word.val * 4 + byte.val]!)
    let parent := Pure.parentOutput (cv left) (cv right)
    unless (Pure.cvBytes parent.chainingValue).toList == expectedCV && parent.rootHash.toList == expectedRoot do
      throw (IO.userError "pure Blake3 internal parent differs")
    unless (Pure.hash (left ++ right)).val.data.toList == expectedOrdinary do
      throw (IO.userError "pure Blake3 digest-pair hash differs")
  IO.println s!"Pure Blake3: 2 known answers, 258 inputs, 58 splits, 42 chunks and 64 parents passed (C={compareC}, Rust={compareRust})"

end Blake3.PureTests
