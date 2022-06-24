{
  description = "An exploration of GRIFFIN with decision tranformers";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils }:
    let out = system:
      let
        useCuda = system == "x86_64-linux";
        pkgs = import nixpkgs {
          inherit system;
          config.cudaSupport = useCuda;
          config.allowUnfree = true;
          overlays = [
            (import ./python-overlay.nix)
          ];
        };
        python = pkgs.python39;
        pythonPackages = python.pkgs;

        pythonEnv = python.withPackages (ps: with ps; [
          jax
          jaxlib
          numpy
          tensorflow
          flax
          atari-py
          dopamine-rl
          pytorch
          transformers
          # Dev dependencies
          black
          ipdb
          ipython
          isort
          pytest
        ]);

        buildInputs = with pkgs; [
          pythonEnv
        ] ++ pkgs.lib.optionals useCuda (with pkgs; [
          linuxPackages.nvidia_x11
        ]);
      in
      {
        devShell = pkgs.mkShell {
          inherit buildInputs;
          shellHook = ''
            export PYTHONFAULTHANDLER=1
            export PYTHONBREAKPOINT=ipdb.set_trace
            set -o allexport
            source .env
            set +o allexport
          '' + pkgs.lib.optionalString useCuda ''
            export CUDA_PATH=${pkgs.cudatoolkit}
            export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
            export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
            export EXTRA_CCFLAGS="-I/usr/include"
          '';
        };
      }; in with flake-utils.lib; eachSystem defaultSystems out;
}
