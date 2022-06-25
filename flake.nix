{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    let out = system:
      let
        useCuda = system == "x86_64-linux";
        pkgs = import nixpkgs {
          inherit system;
          config.cudaSupport = useCuda;
          config.allowUnfree = true;
        };
        inherit (pkgs) poetry2nix lib stdenv fetchurl;
        inherit (pkgs.cudaPackages) cudatoolkit;
        inherit (pkgs.linuxPackages) nvidia_x11;
        python = pkgs.python39;
        pythonEnv = poetry2nix.mkPoetryEnv {
          inherit python;
          projectDir = ./.;
          preferWheels = true;
          overrides = poetry2nix.overrides.withDefaults (pyfinal: pyprev: rec {
            # Provide non-python dependencies.
            tokenizers = pyprev.tokenizers.overridePythonAttrs (old: with pkgs; {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ (with rustPlatform; [
                rust.rustc
                rust.cargo
                pyfinal.setuptools-rust
                pkg-config
              ]);
              buildInputs = [
                openssl
              ] ++ lib.optionals stdenv.isDarwin [
                libiconv
                darwin.Security
              ] ++ lib.optionals stdenv.isLinux [
                rustc
              ];
            });
            # Use cuda-enabled pytorch as required
            torch =
              if useCuda then
              # Override the nixpkgs bin version instead of
              # poetry2nix version so that rpath is set correctly.
                pyprev.pytorch-bin.overridePythonAttrs
                  (old: {
                    inherit (old) pname version;
                    src = fetchurl {
                      url = "https://download.pytorch.org/whl/cu115/torch-1.11.0%2Bcu115-cp39-cp39-linux_x86_64.whl";
                      sha256 = "sha256-64HQZ7vP6ETJXF0n4myXqWqJNCfMRosiWerw7ZPaHH0=";
                    };
                  }) else pyprev.torch;
          });
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = [
            pythonEnv
          ] ++ lib.optionals useCuda [
            nvidia_x11
            cudatoolkit
          ];
          shellHook = ''
            export pythonfaulthandler=1
            export pythonbreakpoint=ipdb.set_trace
            set -o allexport
            source .env
            set +o allexport
          '' + pkgs.lib.optionalString useCuda ''
            export CUDA_PATH=${cudatoolkit.lib}
            export LD_LIBRARY_PATH=${cudatoolkit.lib}/lib:${nvidia_x11}/lib
            export EXTRA_LDFLAGS="-l/lib -l${nvidia_x11}/lib"
            export EXTRA_CCFLAGS="-i/usr/include"
          '';
        };
      }; in with utils.lib; eachSystem defaultSystems out;

}
