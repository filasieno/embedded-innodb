# Minimal wrapper to load the default flake dev shell
let
  flake  = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;
in
flake.devShells.${system}.default
