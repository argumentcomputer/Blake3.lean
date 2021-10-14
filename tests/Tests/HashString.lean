import Blake3

open Blake3

def String.toByteArray (s : String) : ByteArray :=
  (List.map
    (fun c : Char => c.toNat.toUInt8) s.toList).toByteArray

#eval (hash "hello".toByteArray)