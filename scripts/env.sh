#!/bin/bash
function ib-configure() {
    cmake -G Ninja -B build -S . -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX="$PWD/build/out" -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DUNIT_TESTING=ON -DDISABLE_XA=OFF
}

function ib-build() {
    ninja -C build -v
}

function ib-run-tests() {
    itest_cfg
    itest_cursor
    itest_ddl
    itest_deadlock
    itest_dict
    itest_dict-2
    itest_drop
    itest_index
    itest_logger
    itest_mt_stress
    itest_parallel_reader
    itest_perf1
    itest_recover
    itest_search
    itest_shutdown
    itest_status
    itest_tablename
    itest_test1
    itest_test2
    itest_test3
    itest_test5
    itest_types
    itest_update
}

function ib-run-utests() {
    ctest --test-dir build/debug
}

## ib-cov — Generate code coverage reports with gcovr
##
## Usage:
##   ib-cov [--build-dir DIR] [--no-run-tests] [--clean] [--open] [--help]
##
## Requirements:
##   - Configure/build with GCC and -DENABLE_GCOV=ON (injects --coverage flags)
##   - Run inside "nix develop" so gcovr/ctest/cmake are available
##
## Behavior:
##   - Runs tests via ctest (unless --no-run-tests)
##   - Writes reports to $PROJECT_ROOT/coverage:
##       coverage.xml, coverage-index.html (summary), coverage-details.html
##   - Excludes test sources by default
function ib-cov() {
    # Parse options
    local BUILD_DIR="build/debug"
    local RUN_TESTS=1
    local DO_CLEAN=0
    local DO_OPEN=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build-dir)
                BUILD_DIR="$2"; shift 2;;
            --no-run-tests)
                RUN_TESTS=0; shift;;
            --clean)
                DO_CLEAN=1; shift;;
            --open)
                DO_OPEN=1; shift;;
            -h|--help)
                echo "ib-cov - Generate GCOV/HTML coverage reports"
                echo "Usage: ib-cov [--build-dir DIR] [--no-run-tests] [--clean] [--open]"
                echo "Default build dir: build/debug"
                return 0;;
            *)
                echo "ib-cov: unknown option: $1" 1>&2; return 2;;
        esac
    done

    # Resolve project root (prefer git, fall back to script dir)
    local PROJECT_ROOT
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

    # Tool checks
    if ! command -v gcovr >/dev/null 2>&1; then
        echo "gcovr not found. Enter the dev shell: nix develop" 1>&2
        return 1
    fi
    if ! command -v ctest >/dev/null 2>&1; then
        echo "ctest not found. Enter the dev shell: nix develop" 1>&2
        return 1
    fi
    if ! command -v cmake >/dev/null 2>&1; then
        echo "cmake not found. Enter the dev shell: nix develop" 1>&2
        return 1
    fi

    # Validate build directory
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "ib-cov: build directory not found: $BUILD_DIR" 1>&2
        return 1
    fi

    # Output directory (inside build tree)
    local OUT_DIR="$BUILD_DIR/innodb/coverage"
    echo "Coverage folder: $OUT_DIR"
    [[ $DO_CLEAN -eq 1 ]] && rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"

    # Warn if build likely lacks coverage instrumentation
    if [[ -f "$BUILD_DIR/compile_commands.json" ]]; then
        if ! grep -q -- "--coverage" "$BUILD_DIR/compile_commands.json"; then
            echo "Warning: build does not appear to be instrumented. Configure with -DENABLE_GCOV=ON" 1>&2
        fi
    fi

    # Prefer the CMake 'coverage' target if available; otherwise run ctest+gcovr
    if cmake --build "$BUILD_DIR" --target coverage >/dev/null 2>&1; then
        echo "Ran CMake 'coverage' target"
    else
        [[ $RUN_TESTS -eq 1 ]] && ctest --test-dir "$BUILD_DIR" --output-on-failure | cat
        gcovr -r "$PROJECT_ROOT" \
            --object-directory "$BUILD_DIR" \
            --exclude '.*tests/.*' \
            --exclude '.*unit-tests/.*' \
            --xml -o "$OUT_DIR/coverage.xml" \
            --html "$OUT_DIR/coverage-index.html" \
            --html-details -o "$OUT_DIR/coverage-details.html"
    fi

    echo "Coverage written: $OUT_DIR/coverage-index.html (and $OUT_DIR/coverage.xml)"
    if [[ $DO_OPEN -eq 1 ]]; then
        command -v xdg-open >/dev/null 2>&1 && xdg-open "$OUT_DIR/coverage-index.html" >/dev/null 2>&1 || true
    fi
}