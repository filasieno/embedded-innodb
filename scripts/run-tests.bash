#!/bin/bash

declare script_dir
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

declare script_name=${BASH_SOURCE[0]##*/}

declare source_dir
source_dir=$(cd "$script_dir/.." && pwd)

declare build_dir=$source_dir/build

declare config=${script_name%.*}; config=${config#run-tests-*}

if [[ $config == run-tests ]]; then
	config=Debug
fi

if [[ ! -e $build_dir || ! -d $build_dir ]]; then
	"$script_dir/configure.bash"
fi

# CMake variable, force cmake to detect a color enabled terminal, in ninja
# commands are piped.
export CLICOLOR_FORCE=1

export GTEST_COLOR=yes 

exec ctest --test-dir "$build_dir" -C "$config" "$@"