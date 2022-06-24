final: prev:
let
  pythonOverrides = (import ./python-overrides.nix { inherit final prev; });
in
{
  python310 = prev.python310.override (old: {
    packageOverrides = pythonOverrides;
  });
  python39 = prev.python39.override (old: {
    packageOverrides = pythonOverrides;
  });
}
