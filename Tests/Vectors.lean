/-
Copyright (c) 2026 Argument Computer Corporation.
SPDX-License-Identifier: MIT OR Apache-2.0
-/

/-! Schema for the native component vectors in `Tests/PureVectors.lean`, which
`rust/examples/pure_vectors.rs` generates as one `Vectors` literal. Inputs are
described by their parameters; `Tests/Pure.lean` rebuilds the bytes with the
generator's formula. 32-byte values are lowercase hex strings, as in the
BLAKE3 team's test vectors. -/

namespace Blake3.PureTests

/-- Chaining value of one chunk at an explicit chunk counter. -/
structure ChunkVector where
  counter : Nat
  length : Nat
  cv : String

/-- Merges of two 32-byte chaining values derived from `salt`: the internal
parent chaining value, the root hash of the same pair, and the ordinary hash
of their 64-byte concatenation, which must differ from both. -/
structure ParentVector where
  salt : Nat
  cv : String
  root : String
  ordinary : String

structure Vectors where
  /-- Version of the Rust BLAKE3 crate that produced the vectors. -/
  reference : String
  chunks : List ChunkVector
  parents : List ParentVector

end Blake3.PureTests
