#!/bin/bash

# This bash script performs all of the tasks
# required to build DOD-OS in all planned configurations.
# The most common configuration will be deploying the OS
# to a removable storage device for regular use.

# Beyond the required_programs (which may be sourced from anywhere)
# the script will query the --package-server given (default of http://mirrors.acm.wpi.edu/archlinux/)

# Ensure any failure halts the entire script
set -e

{ # check that all required programs are available
  required_programs=(
    bash true false
    cat mkdir
    sed awk grep curl

  )


  for program in "${required_programs[@]}" ; do
    if ! command -v $program &> /dev/null ; then
      echo "[ error ] builder.sh relies on the program $program for it's operation."
      echo "[ error ] Please install $program and ensure it is on your PATH (currently set to PATH=$PATH)"
      exit 1
    fi
  done
}

{ # Set defaults, parse arguments and store in variables
  PACKAGE_SERVER='http://mirrors.kernel.org/archlinux'
  ARCH='x86_64'
  VERBOSE=false
  TARGET_DIRECTORY=/dev/null
  TARGET_DISK=/dev/null
  DEPLOYMENT_TYPE=container # Possible values are "container" or "disk"

  HELP_TEXT=$(cat <<EOF
Usage: $0 [options]

Where [options] consist of:

  -p|--package-server
     Specify where to download packages for the initial OS. Defaults to $PACKAGE_SERVER

  -a|--arch
     Specify the architecture of the system being built. Defaults to $ARCH

  -d|--deployment-type
     Specify the type of deployment. Valid values are container, disk.
     Defaults to $DEPLOYMENT_TYPE

  --target-directory
     When building a container, this specifies the directory of the root FS.
     When building a disk, this specifies the mount point to be used for the root partition (less common).
     Defaults to $TARGET_DIRECTORY

  --target-disk
     When building a disk, this specifies the block device to be partitioned and mounted.
     Note that no support exists for custom partitioning - the entire disk will be used, which is a destructive operation that will remove existing data.
     Please ensure you have the correct disk (/dev/sda, /dev/nvme0n1, etc.) before targeting.
     Defaults to $TARGET_DISK

  -h|--help
     Print this document

  -v|--verbose
     Print additional details to stderr about what actions the script is taking

EOF
)

  POSITIONAL=()
  while [[ $# -gt 0 ]] ; do
    key="$1"

    case $key in
        -p|--package-server)
          PACKAGE_SERVER="$2"
          shift # past argument
          shift # past value
        ;;
        -a|--arch)
          ARCH="$2"
          shift # past argument
          shift # past value
        ;;
        --target-directory)
          TARGET_DIRECTORY="$2"
          shift # past argument
          shift # past value
        ;;
        --target-disk)
          TARGET_DISK="$2"
          shift # past argument
          shift # past value
        ;;
        -d|--deployment-type)
          DEPLOYMENT_TYPE="$2"
          shift # past argument
          shift # past value
          if !( [[ "$DEPLOYMENT_TYPE" == "container" ]] || [[ "$DEPLOYMENT_TYPE" == "disk" ]] ) ; then
            echo "[ error ] Unknown --deployment-type $DEPLOYMENT_TYPE, valid values are container,disk."
            exit 1
          fi
        ;;
        -v|--verbose)
          VERBOSE=true
          shift # past argument
        ;;
        -h|--help)
          echo "$HELP_TEXT"
          exit 0
        ;;
        *)    # unknown option
          POSITIONAL+=("$1") # save it in an array for later
          shift # past argument
        ;;
    esac
  done
  # restore positional parameters
  set -- "${POSITIONAL[@]}"

  # Post-process some arguments
  
  # Remove trailing '/' if given:
  PACKAGE_SERVER=${PACKAGE_SERVER%/}

}

cat <<EOF
=== OS Configuration ===
PACKAGE_SERVER=$PACKAGE_SERVER
ARCH=$ARCH
VERBOSE=$VERBOSE
TARGET_DIRECTORY=$TARGET_DIRECTORY
TARGET_DISK=$TARGET_DISK
DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE
EOF

root_fs="$TARGET_DIRECTORY"

if [[ "$DEPLOYMENT_TYPE" == disk ]] ; then
  # partition disk

  # Mount partitions to $root_fs

  echo '[ todo ] ^^^^^^^^'
  exit 1
fi

if ! [[ -e "$root_fs" ]] ; then
  mkdir -p "$root_fs"
fi

# Utility functions
extract_href() {
  sed -n '/<a / s/^.*<a [^>]*href="\([^\"]*\)".*$/\1/p'
}

# Stage 1 tools

download_and_extract_package() {
  local OS_ROOT=$1 PACKAGE_NAME=$2
  echo "[info ] Installing $PACKAGE_NAME to $OS_ROOT"

  if [[ "$ARCH" == arm* || "$ARCH" == aarch64 ]]; then
    package_core_url="$PACKAGE_SERVER/$ARCH/core"
  else
    package_core_url="$PACKAGE_SERVER/core/os/$ARCH/"
  fi

  packages_list_url=$(curl -L -s "$package_core_url" | extract_href | awk -F"/" '{print $NF}' | sort -rn)
  cat <<EOF
package_core_url=$package_core_url
packages_list=$packages_list
EOF


}

stage1_packages=(
  # Packages needed by pacman (see https://github.com/tokland/arch-bootstrap)
  acl archlinux-keyring attr bzip2 curl expat glibc gpgme libarchive
  libassuan libgpg-error libnghttp2 libssh2 lzo openssl pacman pacman-mirrorlist xz zlib
  krb5 e2fsprogs keyutils libidn2 libunistring gcc-libs lz4 libpsl icu libunistring zstd
  # Common unix tools
  coreutils bash grep gawk file tar systemd sed
)

for package in "${stage1_packages[@]}" ; do
  download_and_extract_package "$root_fs" "$package"
done






