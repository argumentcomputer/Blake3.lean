/-
BinaryTools: Utilities for displaying and manipulating Binary data.
-/

namespace Blake3
/-
Simplification rules for ensuring type safety of Blake3Hash
-/
@[simp] theorem ByteArray.size_empty : ByteArray.empty.size = 0 :=
rfl

@[simp] theorem ByteArray.size_push (B : ByteArray) (a : UInt8) : (B.push a).size = B.size + 1 :=
by { cases B; simp only [ByteArray.push, ByteArray.size, Array.size_push] }

@[simp] theorem List.to_ByteArray_size : (L : List UInt8) → L.toByteArray.size = L.length
| [] => rfl
| a::l => by simp [List.toByteArray, to_ByteArray_loop_size]
where to_ByteArray_loop_size :
  (L : List UInt8) → (B : ByteArray) → (List.toByteArray.loop L B).size = L.length + B.size
| [], B => by simp [List.toByteArray.loop]
| a::l, B => by
    simp [List.toByteArray.loop, to_ByteArray_loop_size]
    rw [Nat.add_succ, Nat.succ_add]

universe u
universe v

/-
Type class for default conversion between two types.
-/
class Into (Target: Type v) (Source: Type u) :=
  (into: Source → Target)

export Into (into)

instance (A: Type u) : Into A A := ⟨id⟩

def String.toByteArray (s : String) : ByteArray :=
  (List.map
    (fun c : Char => c.toNat.toUInt8) s.toList).toByteArray

instance : Into ByteArray String := {
  into := String.toUTF8
}

namespace Alphabet
def base2: String := "01"
def base8: String := "01234567"
def base10: String := "0123456789"
def base16: String := "0123456789abcdef"
def base16upper: String := "0123456789ABCDEF"
def base32: String := "abcdefghijklmnopqrstuvwxyz234567"
def base32upper: String := "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
def base32hex : String := "0123456789abcdefghijklmnopqrstuv"
def base32hexupper : String := "0123456789ABCDEFGHIJKLMNOPQRSTUV"
def base32z : String := "ybndrfg8ejkmcpqxot1uwisza345h769"
def base36 : String := "0123456789abcdefghijklmnopqrstuvwxyz"
def base36upper : String := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
def base58flickr : String := 
  "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"
def base58btc : String := 
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def base64 : String := 
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
def base64url : String := 
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

end Alphabet

/-
Encode a ByteArray as a base64 String
-/
def toBase64 {I: Type u} [Into ByteArray I] (input : I) (pad: Bool := true) : String := Id.run <| do
  let input : ByteArray := Into.into input
  let x := ByteArray.size input % 3
  let mut bytes := input
  let mut str := ""
  if x == 1 then bytes := bytes.append [0x00, 0x00].toByteArray
  if x == 2 then bytes := bytes.append [0x00].toByteArray
  for i in [:(bytes.size / 3)] do
    let b0 := bytes.data[3 * i]
    let b1 := bytes.data[3 * i + 1]
    let b2 := bytes.data[3 * i + 2]
    let s0 := b0.shiftRight 2
    let s1 := UInt8.xor
      ((b0.land 0b00000011).shiftLeft 4) 
      ((b1.land 0b11110000).shiftRight 4)
    let s2 := UInt8.xor
      ((b1.land 0b00001111).shiftLeft 2) 
      ((b2.land 0b11000000).shiftRight 6)
    let s3 := b2.land 0b00111111
    str := str.push (Alphabet.base64.get s0.toNat)
    str := str.push (Alphabet.base64.get s1.toNat)
    str := str.push (Alphabet.base64.get s2.toNat)
    str := str.push (Alphabet.base64.get s3.toNat)
  if pad then do
    if x == 1 then 
      str := str.set (str.length - 1) '='
      str := str.set (str.length - 2) '='
    if x == 2 then 
      str := str.set (str.length - 1) '='
    return str
  else 
    if x == 1 then str := str.dropRight 2
    if x == 2 then str := str.dropRight 1
    return str
