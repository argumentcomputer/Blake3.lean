import Blake3

abbrev input : ByteArray := ⟨#[0]⟩
abbrev output : ByteArray := ⟨#[
   45,  58, 222, 223, 241,  27,  97, 241,
   76, 136, 110,  53, 175, 160,  54, 115,
  109, 205, 135, 167,  77,  39, 181, 193,
   81,   2,  37, 208, 245, 146, 226,  19
]⟩

def main : IO UInt32 := do
  println! s!"BLAKE3 version: {Blake3.version}"
  if (Blake3.hash input).val.data != output.data
    then IO.println "BLAKE3 test failed"; return 1
    else IO.println "BLAKE3 test succeeded"; return 0
