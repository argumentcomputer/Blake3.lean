import YatimaStdLib.ByteVector

@[extern "lean_byte_array_blake3"]
opaque ByteArray.blake3 : @& ByteArray → ByteVector 32
