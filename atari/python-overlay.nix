final: prev:
let
  packageOverrides = python-final: python-prev: {
    # Work-around for PyOpenSSL marked as broken on aarch64-darwin
    # See: https://github.com/NixOS/nixpkgs/pull/172397,
    # https://github.com/pyca/pyopenssl/issues/87
    pyopenssl = python-prev.pyopenssl.overrideAttrs (old: {
      meta = old.meta // { broken = false; };
    });
    # Twisted currently fails tests because of pyopenssl
    # (see linked issues above)
    twisted = python-prev.buildPythonPackage {
      pname = "twisted";
      version = "22.4.0";
      format = "wheel";
      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/db/99/38622ff95bb740bcc991f548eb46295bba62fcb6e907db1987c4d92edd09/Twisted-22.4.0-py3-none-any.whl";
        sha256 = "sha256-+fepH5STJHep/DsWnVf1T5bG50oj142c5UA5p/SJKKI=";
      };
      propagatedBuildInputs = with python-final; [
        automat
        constantly
        hyperlink
        incremental
        setuptools
        typing-extensions
        zope_interface
      ];
    };
    # Test fails on darwin
    cherrypy = python-prev.cherrypy.overrideAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ final.lib.optionals final.stdenv.isDarwin [
        "test_wait_publishes_periodically"
      ];
    });
    # Fix PyTorch on darwin. TODO: remove after https://github.com/NixOS/nixpkgs/pull/177812
    # is merged.
    pytorch = python-prev.pytorch.overrideAttrs (old: {
      meta = old.meta // { broken = final.stdenv.isLinux && final.stdenv.isAarch64; };
      buildInputs = (old.buildInputs or [ ]) ++ final.lib.optionals final.stdenv.isDarwin [
        prev.darwin.apple_sdk.frameworks.CoreServices
        prev.darwin.libobjc
      ];
      postFixup = final.lib.optionalString final.stdenv.isDarwin ''
        for f in $(ls $lib/lib/*.dylib); do
            install_name_tool -id $lib/lib/$(basename $f) $f || true
        done
        install_name_tool -change @rpath/libshm.dylib $lib/lib/libshm.dylib $lib/lib/libtorch_python.dylib
        install_name_tool -change @rpath/libtorch.dylib $lib/lib/libtorch.dylib $lib/lib/libtorch_python.dylib
        install_name_tool -change @rpath/libc10.dylib $lib/lib/libc10.dylib $lib/lib/libtorch_python.dylib
        install_name_tool -change @rpath/libc10.dylib $lib/lib/libc10.dylib $lib/lib/libtorch.dylib
        install_name_tool -change @rpath/libtorch.dylib $lib/lib/libtorch.dylib $lib/lib/libshm.dylib
        install_name_tool -change @rpath/libc10.dylib $lib/lib/libc10.dylib $lib/lib/libshm.dylib
      '';
    });
    # Add altair-saver
    #altair-data-server = python-prev.buildPythonPackage rec {
      #pname = "altair_data_server";
      #version = "0.4.1";
      #src = python-prev.fetchPypi {
        #inherit pname version;
        #sha256 = "sha256-s5IFpIqyZ4Ag/FhznLlzhFh57Racta3d3J3L9aaa6ys=";
      #};
      #propagatedBuildInputs = with python-final; [
        #altair
        #portpicker
        #tornado
      #];
      #doCheck = false;
    #};
    #altair-viewer = python-prev.buildPythonPackage rec {
      #pname = "altair_viewer";
      #version = "0.4.0";
      #src = python-prev.fetchPypi {
        #inherit pname version;
        #sha256 = "sha256-9dM993XLkJRUTxXptXiCJEiPUGz1RscImA0tRML5NTQ=";
      #};
      #propagatedBuildInputs = with python-final; [
        #altair-data-server
        #ipython
      #];
      #doCheck = false;
    #};
    #altair-saver = python-prev.buildPythonPackage rec {
      #pname = "altair_saver";
      #version = "0.5.0";
      #src = python-prev.fetchPypi {
        #inherit pname version;
        #sha256 = "sha256-wJi89oaOO6EdsQiQTcO4UVtUUFuJvKX2lScRVIe4h5U=";
      #};
      #propagatedBuildInputs = with python-final; [
        #altair
        #altair-data-server
        #altair-viewer
        #selenium
      #];
      #doCheck = false;
    #};
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
