import Blake3

open Blake3

def String.toByteArray (s : String) : ByteArray :=
  (List.map
    (fun c : Char => c.toNat.toUInt8) s.toList).toByteArray

/- HashString -/
/- #eval Blake3.version -/
/- #eval (hash "hello".toByteArray) -/

def main (args : List String) : IO UInt32 := do
  try
    IO.println Blake3.version
    IO.println (hash "hello".toByteArray)
    pure 0
  catch e =>
    IO.eprintln <| "error: " ++ toString e -- avoid "uncaught exception: ..."
    pure 1
