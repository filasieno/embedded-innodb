{
  # ==============================================================================
  # Embedded InnoDB - Nix Flake Configuration
  # ==============================================================================
  # Author: Fabio N. Filasieno
  #
  # This flake provides a complete, reproducible development and build environment
  # for Embedded InnoDB using modern Nix patterns and best practices.
  #
  # DESIGN PRINCIPLES:
  # ------------------
  # - Minimalism: Focus on essential functionality with clear, maintainable code
  # - Reproducibility: All environments are exactly reproducible across machines
  # - Multi-platform: Support for x86_64 and aarch64 Linux architectures
  # - Developer Experience: Rich development environments with all necessary tools
  #
  # ARCHITECTURAL CHOICES:
  # ----------------------
  # - Uses nixpkgs.legacyPackages instead of import nixpkgs for consistency
  # - Separates buildDeps/runtimeDeps/devTools for clear dependency management
  # - Single mkDevShell function handles both GCC and Clang toolchains
  # - PKG_CONFIG_PATH configured comprehensively for library discovery
  # - Split package outputs ($out for runtime, $dev for development files)
  #
  # FLAKE OUTPUTS:
  # --------------
  # - packages.default: The main Embedded InnoDB library package
  # - devShells.{gcc,clang,default}: Development environments with different compilers
  # - formatter: nixpkgs-fmt for consistent Nix code formatting
  #
  # DEVELOPMENT WORKFLOW:
  # ---------------------
  #   nix develop                   # Enter default Clang devShell
  #   nix develop .#gcc             # Enter GCC devShell
  #   nix develop .#clang           # Enter Clang devShell
  #   nix build                     # Build the package
  #   nix flake check               # Run checks and validation
  #   nix fmt                       # Format Nix files
  #
  # FUTURE IMPROVEMENTS:
  # --------------------
  # - Integrate proper CMake install targets (currently placeholder)
  # - Add checks and tests to flake outputs
  # - Consider flake-parts for better modularity if complexity grows
  # - Add more architectures (e.g., darwin) as needed
  # - Add apps output for executable binaries
  # - Add overlays for custom package modifications
  #
  # ==============================================================================

  description = "Embedded InnoDB Storage Engine";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    libbsthreadpool = {
      url = "path:nix/libbsthreadpool";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, libbsthreadpool }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Common build configuration shared between packages and devShells
      commonConfig = system: {
        pkgs = nixpkgs.legacyPackages.${system};
        bsThreadPool = libbsthreadpool.packages.${system}.default;
      };

      # Build dependencies - tools needed to compile the project
      buildDeps = pkgs: with pkgs; [
        cmake ninja doxygen bison flex pkg-config
        gtest gbenchmark graphviz python3 gcovr lcov
      ];

      # Runtime dependencies - libraries needed at runtime
      runtimeDeps = { pkgs, bsThreadPool }: [
        pkgs.liburing.dev
        pkgs.liburing
        bsThreadPool
      ];

      # Development tools - additional tools for development environment
      devTools = pkgs: with pkgs; [
        cmakeWithGui ccache luajit sysbench bun
      ];

      # Create a development shell with specified compiler toolchain
      mkDevShell = system: stdenv: extraTools:
        let
          config = commonConfig system;
          pkgs = config.pkgs;
        in
        stdenv.mkDerivation {
          name = "embedded-innodb-devshell";

          nativeBuildInputs = buildDeps pkgs ++ devTools pkgs ++ extraTools ++ [ stdenv.cc ];
          buildInputs = runtimeDeps config;

          # Configure PKG_CONFIG_PATH for proper library discovery
          shellHook = ''
            export PKG_CONFIG_PATH="${
              pkgs.lib.concatStringsSep ":" [
                (pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" (runtimeDeps config ++ buildDeps pkgs ++ [ stdenv.cc ]))
                (pkgs.lib.makeSearchPathOutput "dev" "share/pkgconfig" (runtimeDeps config ++ buildDeps pkgs ++ [ stdenv.cc ]))
                (pkgs.lib.makeSearchPath "lib/pkgconfig" (runtimeDeps config ++ buildDeps pkgs ++ [ stdenv.cc ]))
                (pkgs.lib.makeSearchPath "share/pkgconfig" (runtimeDeps config ++ buildDeps pkgs ++ [ stdenv.cc ]))
              ]
            }:$PKG_CONFIG_PATH"

            # Project-specific environment setup
            export PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
            export PATH="$PROJECT_ROOT/build/tests/bin:$PROJECT_ROOT/build/unit_tests/bin:$PROJECT_ROOT/scripts:$PATH"

            # Custom prompt
            export PS1="\[\e[1;33m\](embedded-innodb)\[\e[0m\] \[\e[1;32m\][\u@\h:\w]\$\[\e[0m\] "

            # Source project environment if available
            [ -f "$PROJECT_ROOT/scripts/env.sh" ] && source "$PROJECT_ROOT/scripts/env.sh"

            echo "Using compiler: $CC ($CXX)"
          '';

          phases = [ "installPhase" ];
          installPhase = "mkdir -p $out";
        };

    in
    {
      packages = forAllSystems (system: {
        default = let
          config = commonConfig system;
          pkgs = config.pkgs;
        in
        pkgs.stdenv.mkDerivation {
          pname = "embedded-innodb";
          version = "0.1";
          src = ./.;

          outputs = [ "out" "dev" ];

          nativeBuildInputs = buildDeps pkgs ++ [ pkgs.stdenv.cc ];
          buildInputs = runtimeDeps config;
          propagatedBuildInputs = [ pkgs.liburing ];

          doCheck = false;

          configurePhase = "cmake --preset debug";
          buildPhase = "cmake --preset debug --build";

          # TODO: Replace with proper CMake install integration
          installPhase = ''
            mkdir -p $out/lib $dev/include $dev/lib
            touch $out/lib/placeholder $dev/include/placeholder $dev/lib/placeholder
          '';

          meta = with pkgs.lib; {
            description = "Standalone Embedded InnoDB library";
            homepage = "https://github.com/sunbains/embedded-innodb";
            license = licenses.gpl2Only;
            platforms = platforms.linux;
            maintainers = [ "Sunny Bains" "Fabio N. Filasieno" ];
          };
        };
      });

      devShells = forAllSystems (system: 
        let
          pkgs = import nixpkgs { inherit system; overlays = []; };
        in 
        {
          default = self.devShells.${system}.clang;

          gcc     = mkDevShell system (pkgs.stdenv)      (with pkgs; [ gcovr lcov ]);
          clang   = mkDevShell system (pkgs.clangStdenv) (with pkgs; [ clang-tools ]);
        });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}
