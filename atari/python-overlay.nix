final: prev:
let
  packageOverrides = python-final: python-prev: {
    atari-py = python-prev.buildPythonPackage rec {
      pname = "atari-py";
      version = "0.2.9";
      src = python-prev.fetchPypi {
        inherit pname version;
        sha256 = "sha256-yxtDVePktijict6DF+jc7q3uq7ghszgAQJ4X/8MJXiA=";
      };
      doCheck = false;
      nativeBuildInputs = [ prev.cmake ];
      buildInputs = with python-final; [ 
        prev.zlib 
        numpy
        six
      ];
      dontUseCmakeConfigure = true;
    };
    blosc = python-prev.buildPythonPackage rec {
      pname = "blosc";
      version = "1.10.6";
      src = python-prev.fetchPypi {
        inherit pname version;
        sha256 = "sha256-VdnVe4XW7uwBDGw5nygg+W9Wbcy8bd/u+2BQH44QtUg=";
      };
      doCheck = false;
      nativeBuildInputs = [ prev.cmake ];
      buildInputs = with python-final; [ 
        scikit-build
      ];
      dontUseCmakeConfigure = true;
    };
    dopamine-rl = python-prev.buildPythonPackage {
      pname = "dopamine-rl";
      version = "4.0.5";
      format = "wheel";
      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/99/6f/fe7450607c882038d05024a4a781bd9efbb004795e944265d178c97babde/dopamine_rl-4.0.5-py3-none-any.whl";
        sha256 = "sha256-n0u1zcKW8puT0m6nhNc9EVbTlwRPDnTDib6oYC5BN7Q=";
      };
      buildInputs = with python-final; [ 
        gin-config
        pillow
        numpy
        tensorflow-probability
        jaxlib
        flax
      ];
      propagatedBuildInputs = with python-final; [];
    };
  };
in
{
  python310 = prev.python310.override { inherit packageOverrides; };
  python39 = prev.python39.override { inherit packageOverrides; };
  # Test fails on darwin
  thrift = prev.thrift.overrideAttrs (old: {
    disabledTests = (old.disabledTests or [ ]) ++ final.lib.optionals final.stdenv.isDarwin [
      "concurrency_test"
    ];
  });
}
