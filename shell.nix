# Compatibility wrapper to load the `default` flake devShell
let
  flake  = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;
in
flake.devShells.${system}.default
