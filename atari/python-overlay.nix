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
