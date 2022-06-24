{ final
, prev
}:
let
  inherit (final) lib stdenv fetchurl fetchFromGitHub cudaPackages;
in
python-final: python-prev: {
    pytorch = python-prev.pytorch-bin;

    tensorflow = python-prev.tensorflow-bin;

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
      src = fetchFromGitHub {
        owner = "google";
        repo = "dopamine";
        # There are no release branches / tags. Using commit hash.
        rev = "4ced9fa438c51663d86c5a2b50d976ad87d1641a"; 
        sha256 = "sha256-O+fzxFhfC1KTCOJcG/fUXOBK2uHzjj/0uPzrI33cGWo=";
      };
      propagatedBuildInputs = with python-final; [
        flax
        gin-config
        gym
        jaxlib
        numpy
        pandas
        pillow
        pygame
        tensorflow
        tensorflow-probability
        tf-slim
        opencv4
        decorator
      ];
      # Work around this package's difficulty finding dependencies.
      preConfigure = ''
        substituteInPlace setup.py \
        --replace "'tensorflow >= 2.2.0'," "" \
        --replace "'opencv-python >= 3.4.8.29'," "" \
        --replace "'gym[atari] >= 0.13.1'," ""
      '';
      doCheck = false;
    };

    tf-slim = python-prev.buildPythonPackage rec {
      pname = "tf-slim";
      version = "1.1.0";
      format = "wheel";
      src = fetchurl {
        url = "https://files.pythonhosted.org/packages/02/97/b0f4a64df018ca018cc035d44f2ef08f91e2e8aa67271f6f19633a015ff7/tf_slim-1.1.0-py2.py3-none-any.whl";
        sha256 = "sha256-+iurY7OSW9QmARAufxeNzpl/UldCWWv0BPqKaRjhRv8=";
      };
      buildInputs = with python-final; [
        absl-py
      ];
    };
}
