import Lake

open Lake DSL

package Blake3

lean_lib Blake3

target cloneBlake3 pkg : GitRepo := do
  let repoDir : GitRepo := pkg.dir / "blake3"
  let alreadyCloned ← repoDir.dir.pathExists
  if !alreadyCloned then
    GitRepo.clone "https://github.com/BLAKE3-team/BLAKE3" repoDir
  return pure repoDir

def blake3CDir (blake3Repo : GitRepo) : System.FilePath :=
  blake3Repo.dir / "c"

opaque BLAKE3_FLAGS : Array String :=
  #["-DBLAKE3_NO_SSE2", "-DBLAKE3_NO_SSE41", "-DBLAKE3_NO_AVX2", "-DBLAKE3_NO_AVX512"]

def buildBlake3Obj (pkg : NPackage _package.name) (fileName : String) (addFlags : Bool) := do
  let blake3Repo ← cloneBlake3.fetch >>= (·.await)
  let cDir := blake3CDir blake3Repo
  let srcJob ← inputTextFile $ cDir / (fileName ++ ".c")
  let oFile := pkg.buildDir / (fileName ++ ".o")
  let includeArgs := #["-I", cDir.toString]
  let weakArgs := if addFlags then includeArgs ++ BLAKE3_FLAGS else includeArgs
  buildO oFile srcJob weakArgs #["-fPIC"] "cc" getLeanTrace

target ffi.o pkg : System.FilePath := do
  let blake3Repo ← cloneBlake3.fetch >>= (·.await)
  let oFile := pkg.buildDir / "ffi.o"
  let srcJob ← inputTextFile $ pkg.dir / "ffi.c"
  let includeDir ← getLeanIncludeDir
  let cDir := blake3CDir blake3Repo
  let weakArgs := #["-I", includeDir.toString, "-I", cDir.toString]
  buildO oFile srcJob weakArgs #["-fPIC"] "cc" getLeanTrace

extern_lib ffi pkg := do
  let blake3O ← buildBlake3Obj pkg "blake3" false
  let blake3DispatchO ← buildBlake3Obj pkg "blake3_dispatch" true
  let blake3PortableO ← buildBlake3Obj pkg "blake3_portable" true
  let ffiO ← ffi.o.fetch
  let name := nameToStaticLib "ffi"
  buildStaticLib (pkg.nativeLibDir / name) #[blake3O, blake3DispatchO, blake3PortableO, ffiO]
