{
  description = "A template for python development with Nix Flakes.";
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
          overlays = [
            (import ./python-overlay.nix)
          ];
        };
        python = pkgs.python310;
        pythonPackages = python.pkgs;
        pythonEnv = python.withPackages (ps: with ps; [
          atari-py
          gym
          numpy
          opencv4
          pillow
          pytorch-bin
          tqdm
          # Dev dependencies
          black
          ipdb
          ipython
          isort
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
      }; in with utils.lib; eachSystem defaultSystems out;
}
