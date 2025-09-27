{
  description = "Embedded InnoDB";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    libbsthreadpool = {
      url = "path:nix/libbsthreadpool";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, libbsthreadpool }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      commonFor = system:
        let
          pkgs = import nixpkgs { inherit system; };

          bsThreadPoolPkg = libbsthreadpool.packages.${system}.default;
          
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

          propagatedBuildInputs = [
            pkgs.liburing
          ];
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

            # Split outputs: shared libs in $out, headers and static libs in $dev
            outputs = [ "out" "dev" ];

            nativeBuildInputs     = common.nativeBuildInputs;
            buildInputs           = common.buildInputs ++ (with pkgs; [ ]);
            propagatedBuildInputs = common.propagatedBuildInputs ;
           
            doCheck = false;

            configurePhase = ''
              cmake --preset debug
            '';
            
            buildPhase = ''
              cmake --build --preset debug
            '';

            installPhase = ''
              # Expose compile_commands.json for editor tooling
              mkdir -p $out/lib
              mkdir -p $dev/include
              mkdir -p $dev/lib

              touch $dev/lib/dev
              touch $dev/include/dev
              touch $out/lib/out
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
                sysbench
                bun
                clang-tools
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
