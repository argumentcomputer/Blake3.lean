import Lake

open Lake DSL

package Blake3

@[default_target]
lean_lib Blake3 where
  precompileModules := true

@[test_driver]
lean_exe Blake3Test

-- BLAKE3 C source
abbrev blake3RepoURL := "https://github.com/BLAKE3-team/BLAKE3"
abbrev blake3RepoTag := "1.8.3"

target cloneBlake3 pkg : GitRepo := do
  let repoDir : GitRepo := pkg.dir / "blake3"

  -- Clone if it hasn't already been cloned
  let alreadyCloned ← repoDir.dir.pathExists
  if !alreadyCloned then
    GitRepo.clone blake3RepoURL repoDir

  -- Checkout to a fixed tag
  GitRepo.execGit #["fetch", "--tags"] repoDir
  GitRepo.execGit #["checkout", blake3RepoTag] repoDir

  return pure repoDir

def blake3CDir (blake3Repo : GitRepo) : System.FilePath :=
  blake3Repo.dir / "c"

abbrev blake3Flags : Array String := #[
    "-DBLAKE3_NO_SSE2",
    "-DBLAKE3_NO_SSE41",
    "-DBLAKE3_NO_AVX2",
    "-DBLAKE3_NO_AVX512",
    "-DBLAKE3_USE_NEON=0"
  ]

abbrev compiler := "cc"

def buildBlake3Obj (pkg : Package) (fileName : String) := do
  let blake3Repo ← cloneBlake3.fetch >>= (·.await)
  let cDir := blake3CDir blake3Repo
  let srcJob ← inputTextFile $ cDir / fileName |>.addExtension "c"
  let oFile := pkg.buildDir / fileName |>.addExtension "o"
  let includeArgs := #["-fPIC", "-I", cDir.toString]
  let weakArgs := includeArgs ++ blake3Flags

  buildO oFile srcJob weakArgs #[] compiler getLeanTrace

-- C FFI
target ffi_c pkg : System.FilePath := do
  let blake3Repo ← cloneBlake3.fetch >>= (·.await)
  let oFile := pkg.buildDir / "ffi_c.o"
  let srcJob ← inputTextFile $ pkg.dir / "ffi.c"
  let leanIncludeDir ← getLeanIncludeDir
  let cDir := blake3CDir blake3Repo
  let weakArgs := #["-fPIC", "-I", leanIncludeDir.toString, "-I", cDir.toString]

  buildO oFile srcJob weakArgs #[] compiler getLeanTrace

target blake3_c pkg : System.FilePath := do
  -- Gather all `.o` file build jobs
  let blake3O ← buildBlake3Obj pkg "blake3"
  let blake3DispatchO ← buildBlake3Obj pkg "blake3_dispatch"
  let blake3PortableO ← buildBlake3Obj pkg "blake3_portable"
  let ffiO ← ffi_c.fetch
  let oFileJobs := #[blake3O, blake3DispatchO, blake3PortableO, ffiO]

  let name := nameToStaticLib "blake3_c"
  buildStaticLib (pkg.staticLibDir / name) oFileJobs

lean_lib «Blake3.C» where
  roots := #[`Blake3.C]
  precompileModules := true
  moreLinkObjs := #[blake3_c]

-- Rust FFI
target blake3_rs pkg : System.FilePath := do
  proc { cmd := "cargo", args := #["build", "--release"], cwd := pkg.dir / "rust" } (quiet := true)
  let libName := nameToStaticLib "blake3_rs"
  inputBinFile $ pkg.dir / "rust" / "target" / "release" / libName

lean_lib «Blake3.Rust» where
  roots := #[`Blake3.Rust]
  precompileModules := true
  moreLinkObjs := #[blake3_rs]

