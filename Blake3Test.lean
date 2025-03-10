import Blake3

abbrev input : ByteArray := ⟨#[0]⟩
abbrev expectedOutputRegularHashing : ByteArray := ⟨#[
   45,  58, 222, 223, 241,  27,  97, 241,
   76, 136, 110,  53, 175, 160,  54, 115,
  109, 205, 135, 167,  77,  39, 181, 193,
   81,   2,  37, 208, 245, 146, 226,  19
]⟩

-- Good pseudo-random key
abbrev key : Blake3.Blake3Key := .ofBytes ⟨#[
     3, 123,  16, 175,  8, 196, 101, 134,
   144, 184, 221,  34, 25, 106, 122, 200,
   213,  14, 159, 189, 82, 166,  91, 107,
    33,  78,  26, 226, 89,  65, 188, 92
]⟩
abbrev expectedOutputKeyedHashing: ByteArray := ⟨#[
   145, 187, 220, 234, 206, 139, 205, 138,
   220, 103,  35,  65, 199,  96, 210,  18,
   145, 201, 131, 254,  79, 208, 229, 157,
     2,  29,  12,  32,  17, 118, 181, 232
]⟩

-- Context (with "bad" randomness)
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

def hashingFails :=
  (Blake3.hash input).val.data != expectedOutputRegularHashing.data ||
  (Blake3.hashKeyed input key).val.data != expectedOutputKeyedHashing.data ||
  (Blake3.hashDeriveKey input context).val.data != expectedOutputDeriveKeyHashing.data

def spongeFails :=
  let sponge := Blake3.Sponge.init "ix 2025-01-01 16:18:03 content-addressing v1"
  let sponge := sponge.absorb ⟨#[1]⟩
  let sponge := sponge.absorb ⟨#[2]⟩
  let sponge := sponge.absorb ⟨#[3]⟩
  let sponge := sponge.absorb ⟨#[4, 5]⟩
  let output := sponge.squeeze 50
  output.val.data != expectedOutputSponge.data

def main : IO UInt32 := do
  println! s!"BLAKE3 version: {Blake3.version}"
  if hashingFails || spongeFails
    then IO.eprintln "BLAKE3 test failed";    return 1
    else IO.println  "BLAKE3 test succeeded"; return 0
