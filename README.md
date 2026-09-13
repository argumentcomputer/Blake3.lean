# Blake3.lean

The [BLAKE3 hash function](https://github.com/BLAKE3-team/BLAKE3) in Lean:
C and Rust bindings, plus a total pure Lean implementation with checked proofs.

## Usage

Add Blake3 as a dependency in your `lakefile.lean`:

```lean
require Blake3 from git
  "https://github.com/argumentcomputer/Blake3.lean" @ "<commit-hash>"
```

### C backend

```lean
import Blake3.C

def main : IO Unit := do
  let hash := Blake3.C.hash ⟨#[72, 101, 108, 108, 111]⟩  -- "Hello"
  IO.println s!"BLAKE3: {hash.val.toList}"
```

### Pure Lean hashing

```lean
import Blake3.Pure

def helloHash : Blake3.Blake3Hash :=
  Blake3.Pure.hash "Hello".toUTF8
```

`Blake3.Pure.hash` computes an unkeyed 32-byte digest entirely in Lean. Its
definitions are exposed for kernel reduction and proof. It imports neither
FFI backend and has no dependencies beyond this package and Lean's standard
library. Import `Blake3.Pure.Proofs` for byte/word round trips, rotation and
message-schedule properties, exact block framing, canonical tree correctness
and uniqueness, and chunk-counter bounds for inputs shorter than 2^64 bytes.

The pure API currently supports one-shot unkeyed hashing. The C and Rust
backends provide the `HasherOps` interface, including streaming, keyed hashing,
key derivation and variable-length output. The pure implementation prioritizes
explicit checked computation; no performance parity with the native backends
is claimed. The proofs establish the stated algorithmic properties. Collision
resistance and universal refinement of C or Rust are separate obligations.

`lake test` runs the existing backend tests, two standard known answers,
258 pure/native comparisons at block and tree boundaries, 58 subtree
compositions, 42 native chunk vectors including large counters, and 64
internal-parent/digest-pair vectors. It also audits the exact axiom sets of
50 proof roots by traversing checked types, bodies and inductive constructors.
These roots use only `propext`, `Classical.choice` and `Quot.sound`, with no
FFI, opaque BLAKE3 implementation or native-decision axiom in their dependency
closure. The audit checks three generated recursion workers against their
safe source definitions; Lean/Std runtime primitives remain an execution
boundary.

Regenerate the component vectors from the pinned Rust dependency with:

```sh
cd rust
cargo run --locked --release --example pure_vectors > ../Tests/PureVectors.lean
```

### Rust backend

```lean
import Blake3.Rust

def main : IO Unit := do
  let hash := Blake3.Rust.hash ⟨#[72, 101, 108, 108, 111]⟩
  IO.println s!"BLAKE3: {hash.val.toList}"
```

### Keyed hashing and key derivation

Both backends implement the `HasherOps` typeclass, which provides `hash`, `hashKeyed`, and `hashDeriveKey`:

```lean
import Blake3.C
open Blake3

def main : IO Unit := do
  let input : ByteArray := ⟨#[0]⟩

  -- Keyed hash
  let key : Blake3Key := .ofBytes ⟨#[
    3, 123, 16, 175, 8, 196, 101, 134,
    144, 184, 221, 34, 25, 106, 122, 200,
    213, 14, 159, 189, 82, 166, 91, 107,
    33, 78, 26, 226, 89, 65, 188, 92
  ]⟩
  let keyedHash := HasherOps.hashKeyed (H := Blake3.C.Hasher) input key

  -- Derive key
  let context := "example 2025-01-01 context".toUTF8
  let derived := HasherOps.hashDeriveKey (H := Blake3.C.Hasher) input context

  IO.println s!"keyed:   {keyedHash.val.toList}"
  IO.println s!"derived: {derived.val.toList}"
```
