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
    realpath
    cat mkdir
    sed awk grep curl
    md5sum
    tar xz zstd
    sudo chroot tee
    date
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
  TEMP_DIR=/tmp/dod-os-builder
  DO_VERIFICATION=false
  NEW_OS_HOSTNAME=dod-os-$(date +'%Y-%m-%d')

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

  -H|--hostname
     Set the hostname for the build OS.
     Defaults to $NEW_OS_HOSTNAME

  -V|--verify
     Turn on expensive verification steps, such as checking downloaded file integrity with the server instead of assuming downloaded files are complete.
     Defaults to $DO_VERIFICATION

  -t|--temp-dir
     Temporary directory used for caching package lists and downloaded packages.
     Defaults to $TEMP_DIR

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
        -t|--temp-dir)
          TEMP_DIR="$2"
          shift # past argument
          shift # past value
        ;;
        -H|--hostname)
          NEW_OS_HOSTNAME="$2"
          shift # past argument
          shift # past value
        ;;
        -V|--verify)
          DO_VERIFICATION=true
          shift # past arg
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
  TEMP_DIR=${TEMP_DIR%/}

  if ! [[ -e "$TEMP_DIR" ]] ; then
    mkdir -p "$TEMP_DIR"
  fi

}

cat <<EOF
=== OS Configuration ===
PACKAGE_SERVER=$PACKAGE_SERVER
ARCH=$ARCH
VERBOSE=$VERBOSE
TARGET_DIRECTORY=$TARGET_DIRECTORY
TARGET_DISK=$TARGET_DISK
DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE
TEMP_DIR=$TEMP_DIR
DO_VERIFICATION=$DO_VERIFICATION
NEW_OS_HOSTNAME=$NEW_OS_HOSTNAME
EOF

root_fs=$(realpath "$TARGET_DIRECTORY")

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

cached_curl() {
  local URL=$1
  local h=$(md5sum <<<"$URL" | awk '{print $1}')
  local cached_file="$TEMP_DIR/curl_$h"
  if ! [[ -e "$cached_file" ]] ; then
    curl -L -s "$URL" > "$cached_file"
  fi
  cat "$cached_file"
}

uncompress() {
  local FILEPATH=$1 DEST=$2
  
  case "$FILEPATH" in
    *.gz) 
      sudo tar xzf "$FILEPATH" -C "$DEST";;
    *.xz) 
      xz -dc "$FILEPATH" | sudo tar x -C "$DEST";;
    *.zst)
      zstd -dc "$FILEPATH" | sudo tar x -C "$DEST";;
    *)
      debug "Error: unknown package format: $FILEPATH"
      return 1;;
  esac
}

# Stage 1 tools

download_and_extract_package() {
  local OS_ROOT=$1 PACKAGE_NAME=$2
  echo "[ info ] Installing $PACKAGE_NAME to $OS_ROOT"

  if [[ "$ARCH" == arm* || "$ARCH" == aarch64 ]] ; then
    package_core_url="$PACKAGE_SERVER/$ARCH/core"
  else
    package_core_url="$PACKAGE_SERVER/core/os/$ARCH/"
  fi

  packages_list=$(cached_curl "$package_core_url" | extract_href | awk -F"/" '{print $NF}' | sort -rn)

  local FILE=$(echo "$packages_list" | grep -m1 "^$PACKAGE_NAME-[[:digit:]].*\(\.gz\|\.xz\|\.zst\)$")
  test "$FILE" || { echo "Cannot find package $PACKAGE_NAME from the server $package_core_url" ; return 1; }

  local FILEPATH="$TEMP_DIR/$FILE"
  local DL_URL="$package_core_url/$FILE"

  # Fetch the compressed package
  if ! [[ -e "$FILEPATH" ]] ; then
    echo "Downloading $DL_URL"
    curl -L -z "$FILEPATH" -o "$FILEPATH" "$DL_URL"
  else
    if $DO_VERIFICATION ; then
      echo "Verifying $DL_URL"
      curl -L -o "$FILEPATH" "$DL_URL"
    else
      echo "Using cached $FILEPATH"
    fi
  fi

  # Extract to OS root
  uncompress "$FILEPATH" "$OS_ROOT"

}

{ # perform install stage 1: download packages and combine into a root filesystem
  stage1_packages=(
    # Packages needed by pacman (see https://github.com/tokland/arch-bootstrap)
    acl archlinux-keyring attr bzip2 curl expat glibc gpgme libarchive
    libassuan libgpg-error libnghttp2 libssh2 lzo openssl pacman pacman-mirrorlist xz zlib
    krb5 e2fsprogs keyutils libidn2 libunistring gcc-libs lz4 libpsl icu zstd
    # Common unix tools
    coreutils bash grep gawk file tar systemd sed
    # stuff like /lib/
    readline ncurses filesystem
  )

  for package in "${stage1_packages[@]}" ; do
    download_and_extract_package "$root_fs" "$package"
  done

  # Copy in network config from the host
  sudo cp "/etc/resolv.conf" "$root_fs/etc/resolv.conf"

  # Configure the container pacman with the current mirror used to d/l packages from
  if [[ "$ARCH" == arm* || "$ARCH" == aarch64 ]]; then
    echo "Server = $PACKAGE_SERVER/$ARCH/\$repo" | sudo tee "$root_fs/etc/pacman.d/mirrorlist"
  else
    echo "Server = $PACKAGE_SERVER/\$repo/os/$ARCH" | sudo tee "$root_fs/etc/pacman.d/mirrorlist"
  fi

  sudo mkdir -p "$root_fs/dev"
  sudo sed -ie 's/^root:.*$/root:$1$GT9AUpJe$oXANVIjIzcnmOpY07iaGi\/:14657::::::/' "$root_fs/etc/shadow"
  sudo touch "$root_fs/etc/group"
  echo "$NEW_OS_HOSTNAME" | sudo tee "$root_fs/etc/hostname"

  sudo rm -f "$root_fs/etc/mtab"
  echo "rootfs / rootfs rw 0 0" | sudo tee "$root_fs/etc/mtab"
  test -e "$root_fs/dev/null" || sudo  mknod "$root_fs/dev/null" c 1 3
  test -e "$root_fs/dev/random" || sudo mknod -m 0644 "$root_fs/dev/random" c 1 8
  test -e "$root_fs/dev/urandom" || sudo mknod -m 0644 "$root_fs/dev/urandom" c 1 9

  sudo  sed -i "s/^[[:space:]]*\(CheckSpace\)/# \1/" "$root_fs/etc/pacman.conf"
  sudo  sed -i "s/^[[:space:]]*SigLevel[[:space:]]*=.*$/SigLevel = Never/" "$root_fs/etc/pacman.conf"
}

{ # Begin stage 2, where we chroot/nspawn into the directory to run commands within the new OS.

  stage2_packages=(
    ${stage1_packages[*]}
    coreutils bash grep gawk file tar systemd sed
  )

  # Chroot into container and use pacman to install stage2 packages
  sudo LC_ALL=C chroot "$root_fs" /usr/bin/pacman \
      --noconfirm --arch $ARCH -Sy --overwrite \* $stage2_packages

}

cat <<EOF
Container built in $root_fs $(du -sh $root_fs 2>/dev/null | awk '{print $1}')

Try booting it using:
  sudo systemd-nspawn -D $root_fs /bin/bash

EOF



