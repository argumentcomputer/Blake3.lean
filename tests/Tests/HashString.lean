import Blake3

open Blake3


/- HashString -/
/- #eval Blake3.version -/
/- #eval (hash "hello".toByteArray) -/

def main (args : List String) : IO UInt32 := do
  try
    IO.println s!"Blake3 version: {Blake3.version}"
    let tests := #["hello", "More complicated test"]
    for s in tests do
      IO.println s!"blake3('{s}')={(Blake3.hash (String.toByteArray s))}"
    pure 0
  catch e =>
    IO.eprintln <| "error: " ++ toString e -- avoid "uncaught exception: ..."
    pure 1
