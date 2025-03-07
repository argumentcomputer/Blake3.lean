import Blake3

abbrev input0 : ByteArray := ⟨#[0]⟩
abbrev input1 : ByteArray := ⟨#[1, 2]⟩
abbrev input2 : ByteArray := ⟨#[100, 200, 300, 500]⟩

-- Context (with "bad" randomness)
abbrev context : ByteArray := ⟨#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]⟩
abbrev expected_hash: ByteArray := ⟨#[
    166, 107, 165, 19, 213, 250, 88, 197,
    134, 200, 46, 163, 206, 214, 32, 78,
    215, 52, 190, 174, 247, 184, 155, 36,
    70, 10, 134, 138, 136, 110, 172, 144,
    160, 96, 4, 60, 80, 83, 174, 81,
    60, 61, 252, 123, 77, 22, 161, 115,
    59, 125
]⟩

def label := "domain_separation"

def main : IO UInt32 := do

  let sponge := Blake3.StatefulHashObject.Sponge.new Blake3.StatefulHashObject.checkLabel label

  -- Absorbing multiple times
  let sponge := sponge.absorb input0
  let sponge := sponge.absorb input1
  let sponge := sponge.absorb input2

  -- Squeezing
  let sponge := sponge.squeeze 50
  let hash := Blake3.StatefulHashObject.extract_output sponge

  -- Ratcheting
  let _ := sponge.ratchet Blake3.StatefulHashObject.extract_key

  if hash.data != expected_hash.data
    then IO.eprintln "BLAKE3 Sponge test failed";    return 1
    else IO.println  "BLAKE3 Sponge test succeeded"; return 0
