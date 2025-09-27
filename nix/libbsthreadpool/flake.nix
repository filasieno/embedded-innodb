{
  description = "BS::thread_pool: a fast, lightweight, modern, and easy-to-use C++17 / C++20 / C++23 thread pool library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
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
            pname = "libbsthreadpool";
            version = "5.0.0";
            src = pkgs.fetchFromGitHub {
              owner = "bshoshany";
              repo  = "thread-pool";
              rev   = "v5.0.0";
              sha256 = "079j8g4bfzvljvlfidly030shzf0dvdx4rac90654ddpmfvyjd6m";
            };

            dontConfigure = true;
            dontBuild     = true;

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/include"
              # Copy the main headers shipped by the project
              cp -v include/BS_thread_pool.hpp       "$out/include/" || true
              cp -v include/BS_thread_pool_utils.hpp "$out/include/" || true
              # Install pkg-config file
              mkdir -p "$out/lib/pkgconfig"
              install -D ${./libbsthreadpool.pc} "$out/lib/pkgconfig/libbsthreadpool.pc"
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
