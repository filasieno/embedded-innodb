{
  description = "Embedded InnoDB";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    bs-thread-pool = {
      url = "path:nix/bs-thread-pool";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, bs-thread-pool }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      commonFor = system:
        let
          pkgs = import nixpkgs { inherit system; };

          bsThreadPoolPkg = bs-thread-pool.packages.${system}.default;
          
          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            doxygen
            bison
            pkg-config
            gtest
            gbenchmark
            stdenv.cc
            graphviz
            python3
            gcovr
            lcov
          ];

          # Ensure .pc and headers for liburing are available in dev/build envs
          buildInputs = [
            pkgs.liburing
            pkgs.liburing.dev
            pkgs.flex
            bsThreadPoolPkg
          ];

          propagatedBuildInputs = [];
        in
        {
          inherit pkgs nativeBuildInputs buildInputs propagatedBuildInputs;
        };
    in
    {
      packages = forAllSystems (system:
        let
          common = commonFor system;
          pkgs = common.pkgs;
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "embedded-innodb";
            version = "0.1";
            src = ./.;

            nativeBuildInputs = common.nativeBuildInputs;
            
            buildInputs = common.buildInputs
              ++ (with pkgs; [ ]);

            propagatedBuildInputs = common.propagatedBuildInputs;

            # Out-of-source build using Ninja; disable network-bound unit tests
            configurePhase = ''
              cmake \
                -G Ninja \
                -B build -S . \
                -DCMAKE_BUILD_TYPE=Debug \
                -DCMAKE_INSTALL_PREFIX=$out \
                -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
                -DUNIT_TESTING=ON \
                -DDISABLE_XA=OFF \
                -DENABLE_GCOV=ON
            '';

            doCheck = false;

            buildPhase = ''
              ninja -C build -v
            '';

            installPhase = ''
              ninja -C build install
              # Expose compile_commands.json for editor tooling
              mkdir -p $out
              cp -f build/compile_commands.json $out/ || true
            '';

            meta = with pkgs.lib; {
              description = "Standalone Embedded InnoDB library";
              homepage    = "https://github.com/sunny/embedded-innodb";
              license     = licenses.gpl2Only;
              platforms   = platforms.linux;
              maintainers = ["Sunny Bains"];
            };
          };
        });

      devShells = forAllSystems (system:
        let
          common = commonFor system;
          pkgs   = common.pkgs;
          lib = pkgs.lib;
          pcPaths = lib.concatStringsSep ":" [
            (lib.makeSearchPathOutput  "dev"   "lib/pkgconfig"   (common.buildInputs ++ common.nativeBuildInputs))
            (lib.makeSearchPathOutput  "dev"   "share/pkgconfig" (common.buildInputs ++ common.nativeBuildInputs))
            (lib.makeSearchPath        "lib/pkgconfig"           (common.buildInputs ++ common.nativeBuildInputs))
            (lib.makeSearchPath        "share/pkgconfig"         (common.buildInputs ++ common.nativeBuildInputs))
          ];
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [] 
              ++ common.nativeBuildInputs
              ++ (with pkgs; [
                cmakeWithGui
                ccache
                luajit 
                gcovr
                lcov
              ]);

            buildInputs = common.buildInputs;
            
            shellHook = ''
              export PROJECT_ROOT=$(git rev-parse --show-toplevel)
              export PKG_CONFIG_PATH=${pcPaths}:$PKG_CONFIG_PATH
              export PATH=$PROJECT_ROOT/build/tests/bin:$PROJECT_ROOT/build/unit_tests/bin/:$PATH

              # Bold yellow project segment, then green user@host:cwd
              
              YELLOW_BOLD="\[\e[1;33m\]"
              GREEN="\[\e[1;32m\]"
              RESET="\[\e[0m\]"
              export PS1="$YELLOW_BOLD(embedded-innodb)$RESET $GREEN[\u@\h:\w]\$$RESET "

              source $PROJECT_ROOT/scripts/env.sh
              function ib-showpkgs() {
                 echo "lua.dev inc: ${pkgs.luajit}"
              }
            '';
          };
        });

      formatter = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; }; in pkgs.nixpkgs-fmt);
    };
}
