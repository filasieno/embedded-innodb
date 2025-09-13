{
  description = "BS::thread_pool: a fast, lightweight, modern, and easy-to-use C++17 / C++20 / C++23 thread pool library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    
    thread-pool = {
      url = "github:bshoshany/thread-pool?ref=v5.0.0";                  # Pin latest release v5.0.0
      flake = false;                                                    # Upstream repo is not a flake; use as raw source
      narHash = "sha256-1TTpt6u3NVIMSExl0ttuwH2owQCetujolnR/t8hDMh0=";  # Check hash to ensure a deterministic build
    };
  };

  outputs = { self, nixpkgs, thread-pool }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          stdenv = pkgs.stdenvNoCC;
        in
        {
          default = stdenv.mkDerivation {
            pname = "bs-thread-pool";
            version = "5.0.0";
            src = thread-pool;

            dontConfigure = true;
            dontBuild     = true;

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/include"
              # Copy the main headers shipped by the project
              cp -v include/BS_thread_pool.hpp       "$out/include/" || true
              cp -v include/BS_thread_pool_utils.hpp "$out/include/" || true
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "BS::thread_pool: a fast, lightweight, modern, and easy-to-use C++17 / C++20 / C++23 thread pool library";
              homepage = "https://github.com/bshoshany/thread-pool";
              license = licenses.mit;
              platforms = platforms.linux;
              maintainers = ["Fabio N. Filasieno"];
            };
          };
        });

      formatter = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; }; in pkgs.nixpkgs-fmt);
    };
}
