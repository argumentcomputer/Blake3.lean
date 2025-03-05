import Blake3

abbrev input : ByteArray := ⟨#[0]⟩
abbrev expected_output_regular_hashing : ByteArray := ⟨#[
   45,  58, 222, 223, 241,  27,  97, 241,
   76, 136, 110,  53, 175, 160,  54, 115,
  109, 205, 135, 167,  77,  39, 181, 193,
   81,   2,  37, 208, 245, 146, 226,  19
]⟩

-- Good pseudo-random key
abbrev key : ByteArray := ⟨#[3, 123, 16, 175, 8, 196, 101, 134, 144, 184, 221, 34, 25, 106, 122, 200, 213, 14, 159, 189, 82, 166, 91, 107, 33, 78, 26, 226, 89, 65, 188, 92]⟩
abbrev expected_output_keyed_hashing: ByteArray := ⟨#[
   145, 187, 220, 234, 206, 139, 205, 138, 220, 103, 35, 65, 199, 96, 210, 18, 145, 201, 131, 254, 79, 208, 229, 157, 2, 29, 12, 32, 17, 118, 181, 232
]⟩

def main : IO UInt32 := do
  println! s!"BLAKE3 version: {Blake3.version}"
  if
    /- Test 1 -/ (Blake3.hash input).val.data != expected_output_regular_hashing.data ||
    /- Test 2 -/ (Blake3.hash_keyed input key).val.data != expected_output_keyed_hashing.data
          then IO.eprintln "BLAKE3 test failed";    return 1
          else IO.println  "BLAKE3 test succeeded"; return 0
