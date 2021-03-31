#!/bin/sh

# Top-level build tool to compile artifacts for all child packages.

# Ensure any failure halts the entire script
set -e

# Move script to it's own directory to allow invoking from any working directory
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

{ # check that all required programs are available
  required_programs=(
    # For compiling rust packages
    rustc cargo
    # For compiling C packages
    gcc
  )


  for program in "${required_programs[@]}" ; do
    if ! command -v $program &> /dev/null ; then
      echo "[ error ] build.sh relies on the program $program for it's operation."
      echo "[ error ] Please install $program and ensure it is on your PATH (currently set to PATH=$PATH)"
      exit 1
    fi
  done
}

{ # All rust code may be compiled using the same tools
  rust_package_dirs=(
    dod-pam-hwauth
  )

  for package_dir in "${rust_package_dirs[@]}" ; do
    (
      cd $package_dir
      cargo build --release
    )
  done
}







