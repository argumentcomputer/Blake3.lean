# Blake3.lean

Lean bindings to the [BLAKE3 hasher](https://github.com/BLAKE3-team/BLAKE3) for the C and Rust implementations.

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
