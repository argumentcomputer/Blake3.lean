import Blake3

namespace Blake3
namespace Pure

/-
Keeping track of the output state during execution of the hasher
-/
structure Output where
  input_chaining_value : CVWords
  block: ByteArrayFixed 64
  block_len: UInt8
  counter: UInt64
  flags: UInt8
  platform: String

def rootHash (self: Output) : Blake3Hash :=
  -- counter == 0
  -- Platform optimizations
  let hash = compressInPlace self.input_chaining_value self.block self.block_len 0 (self.flags | ROOT)
  -- TODO Proove it
  if h : hash.size = BLAKE3_OUT_LEN then
    ⟨hash, h⟩
  else
    panic! "Incorrect output size"


end Pure
/-
Pure Lean implementation of Blake3 Hash
-/
def pureHash (input : ByteArray) : Blake3Hash :=

