import Blake3.C
import Blake3.Rust

open Blake3

class Blake3Backend (H : Type) [HasherOps H] where
  name : String
  version : String

instance : Blake3Backend Blake3.C.Hasher where
  name := "C"
  version := Blake3.C.version

instance : Blake3Backend Blake3.Rust.Hasher where
  name := "Rust"
  version := Blake3.Rust.version

abbrev input : ByteArray := ⟨#[0]⟩

abbrev key : Blake3Key := .ofBytes ⟨#[
     3, 123,  16, 175,  8, 196, 101, 134,
   144, 184, 221,  34, 25, 106, 122, 200,
   213,  14, 159, 189, 82, 166,  91, 107,
    33,  78,  26, 226, 89,  65, 188, 92
]⟩

abbrev expectedOutputRegularHashing : ByteArray := ⟨#[
   45,  58, 222, 223, 241,  27,  97, 241,
   76, 136, 110,  53, 175, 160,  54, 115,
  109, 205, 135, 167,  77,  39, 181, 193,
   81,   2,  37, 208, 245, 146, 226,  19
]⟩

abbrev expectedOutputKeyedHashing: ByteArray := ⟨#[
   145, 187, 220, 234, 206, 139, 205, 138,
   220, 103,  35,  65, 199,  96, 210,  18,
   145, 201, 131, 254,  79, 208, 229, 157,
     2,  29,  12,  32,  17, 118, 181, 232
]⟩

abbrev context : ByteArray := ⟨#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]⟩

abbrev expectedOutputDeriveKeyHashing: ByteArray := ⟨#[
    34,  57,  22,  43, 164, 211,  65, 131,
    90,  55,  55,  92,  68,  90,  63, 136,
     3, 235,  52, 117, 143, 246, 158, 224,
   178, 170, 234, 211, 148,  21,  97, 183
]⟩

abbrev expectedOutputSponge : ByteArray := ⟨#[
    21, 150, 121,  38, 177,  21,  33, 148, 213, 127,
   208, 231, 200,  18,  46, 115, 244, 188, 245, 188,
   176,  29,  43, 123, 135, 148, 132, 218,  45, 244,
   127, 103, 178,  82, 145,  67,  43, 106, 204, 137,
   154,  99, 175,   9, 196, 102, 126,  72,  27,  86
]⟩

def runTests (H : Type) [HasherOps H] [b : Blake3Backend H] : IO Bool := do
  println! s!"BLAKE3 version ({b.name}): {b.version}"
  let hashFails :=
    (HasherOps.hash (H := H) input).val.data != expectedOutputRegularHashing.data ||
    (HasherOps.hashKeyed (H := H) input key).val.data != expectedOutputKeyedHashing.data ||
    (HasherOps.hashDeriveKey (H := H) input context).val.data != expectedOutputDeriveKeyHashing.data
  let spongeFails :=
    let s : Sponge H := Sponge.init "ix 2025-01-01 16:18:03 content-addressing v1"
    let s := s.absorb ⟨#[1]⟩ |>.absorb ⟨#[2]⟩ |>.absorb ⟨#[3]⟩ |>.absorb ⟨#[4, 5]⟩
    (s.squeeze 50).val.data != expectedOutputSponge.data
  if hashFails || spongeFails
    then IO.eprintln s!"BLAKE3 {b.name} test failed";    return false
    else IO.println  s!"BLAKE3 {b.name} test succeeded"; return true

def main (args : List String) : IO UInt32 := do
  let runC    := args.isEmpty || args.contains "c"
  let runRust := args.isEmpty || args.contains "rust"
  let mut ok := true
  if runC    then ok := (← runTests Blake3.C.Hasher) && ok
  if runRust then ok := (← runTests Blake3.Rust.Hasher) && ok
  return if ok then 0 else 1
