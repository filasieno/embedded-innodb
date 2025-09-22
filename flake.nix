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
              ninja -C build install

              # Expose compile_commands.json for editor tooling
              mkdir -p $out
              
              # Move headers to $dev (Nix convention)
              if [ -d "$out/include" ]; then
                mkdir -p $dev
                mv $out/include $dev/
              fi

              # Install internal headers needed by consumers
              # mkdir -p $dev/include
              # cp -R innodb/src/include/* $dev/include/

              # Install generated config header for consumers
              # if [ -f build/include/ib0config.h ]; then
              #   cp -f build/include/ib0config.h $dev/include/
              # fi

              # Move static library to $dev; keep shared in $out
              if [ -d "$out/lib" ]; then
                mkdir -p $dev/lib
                if ls $out/lib/*.a >/dev/null 2>&1; then
                  mv $out/lib/*.a $dev/lib/
                fi
              fi
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
