#!/bin/bash

# Default values
DECOMP="auto"
COMP=""
ROMSIZE=""
OVERLAYSIZE=""
OVERLAY_FS=""
KEEP_TEMP=false
TEMP_FILE=""
RAW_MODE=false
WORKING_FILE=""

# Help function
usage() {
    echo "Usage: $0 [options] <input file> <output file>"
    echo "Options:"
    echo "  -d <program>         Decompression program (auto detect by default)"
    echo "                       Use 'raw' to process uncompressed file"
    echo "  -c <program>         Compression program (default: same as decompression)"
    echo "                       Use 'raw' to skip compression"
    echo "  -k                   Keep temporary files"
    echo "  -t <file>           Specify temporary file path"
    echo "  --rom-size <size>    Size of /rom partition"
    echo "                       (default: sfs size rounded up to nearest 8MiB)"
    echo "  --overlay-size <size> Size of /overlay partition (default: 128MiB)"
    echo "  --overlay-filesystem <fs> Filesystem for overlay (default: ext4, alt: f2fs)"
    echo "  -h, --help          Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d)
            DECOMP="$2"
            [[ "$DECOMP" == "raw" ]] && RAW_MODE=true
            shift 2
            ;;
        -c)
            COMP="$2"
            [[ "$COMP" == "raw" ]] && RAW_MODE=true
            shift 2
            ;;
        -k)
            KEEP_TEMP=true
            shift
            ;;
        -t)
            TEMP_FILE="$2"
            shift 2
            ;;
        --rom-size)
            ROMSIZE="$2"
            shift 2
            ;;
        --overlay-size)
            OVERLAYSIZE="$2"
            shift 2
            ;;
        --overlay-filesystem)
            OVERLAY_FS="$2"
            if [[ "$OVERLAY_FS" != "ext4" && "$OVERLAY_FS" != "f2fs" ]]; then
                echo "Error: Overlay filesystem must be either ext4 or f2fs"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            elif [[ -z "$OUTPUT_FILE" ]]; then
                OUTPUT_FILE="$1"
            else
                echo "Error: Too many arguments"
                usage
            fi
            shift
            ;;
    esac
done

# convert a human size (e.g. 128M, 64MiB, 1024) to bytes (returns empty on error)
size_to_bytes() {
    local s=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$s" ]]; then
        echo ""
        return
    fi
    if [[ "$s" =~ ^([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi
    if [[ "$s" =~ ^([0-9]+)(k|kb|kib)$ ]]; then
        echo $((${BASH_REMATCH[1]} * 1024))
        return
    fi
    if [[ "$s" =~ ^([0-9]+)(m|mb|mib)$ ]]; then
        echo $((${BASH_REMATCH[1]} * 1024**2))
        return
    fi
    if [[ "$s" =~ ^([0-9]+)(g|gb|gib)$ ]]; then
        echo $((${BASH_REMATCH[1]} * 1024**3))
        return
    fi
    if [[ "$s" =~ ^([0-9]+)(t|tb|tib)$ ]]; then
        echo $((${BASH_REMATCH[1]} * 1024**4))
        return
    fi
    # fallback empty on unrecognized format
    echo ""
}

# Validate required arguments
if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
    echo "Error: Input and output files are required"
    usage
fi

# OVERLAYSIZE is required
if [[ -z "$OVERLAYSIZE" ]]; then
    echo "Error: --overlay-size is required"
    usage
fi

# If compression program is not specified, use the same as decompression
if [[ -z "$COMP" ]]; then
    COMP="$DECOMP"
fi

# Auto-detect compression if DECOMP is "auto"
if [[ "$DECOMP" == "auto" ]]; then
    if file "$INPUT_FILE" | grep -q "gzip compressed"; then
        DECOMP="gzip"
        [[ -z "$COMP" ]] && COMP="gzip"
    elif file "$INPUT_FILE" | grep -q "XZ compressed"; then
        DECOMP="xz"
        [[ -z "$COMP" ]] && COMP="xz"
    elif file "$INPUT_FILE" | grep -q "bzip2 compressed"; then
        DECOMP="bzip2"
        [[ -z "$COMP" ]] && COMP="bzip2"
    elif file "$INPUT_FILE" | grep -q "Zstandard compressed"; then
        DECOMP="zstd"
        [[ -z "$COMP" ]] && COMP="zstd"
    else
        echo "Error: Unable to detect compression format"
        exit 1
    fi
fi

# Validate compression/decompression programs
case "$DECOMP" in
    "gzip"|"xz"|"bzip2"|"zstd"|"raw")
        ;;
    *)
        echo "Error: Unsupported decompression program: $DECOMP"
        exit 1
        ;;
esac

# Validate compression program
case "$COMP" in
    "gzip"|"xz"|"bzip2"|"zstd"|"raw")
        ;;
    *)
        echo "Error: Unsupported compression program: $COMP"
        exit 1
        ;;
esac

# 1) lookup an unused loop device, if not found, exit with error
LOOP_DEVICE=$(losetup -f)
if [[ -z "$LOOP_DEVICE" ]]; then
    echo "Error: No unused loop device found"
    exit 1
fi

# 2) prepare file handling
if [[ "$RAW_MODE" = true ]]; then
    # In raw mode, copy the input file to the output file and use it directly
    if ! cp "$INPUT_FILE" "$OUTPUT_FILE"; then
        echo "Error: Cannot copy input file to output file: $OUTPUT_FILE"
        exit 1
    fi
    WORKING_FILE="$OUTPUT_FILE"
else
    # Normal mode with temporary file handling
    if [[ -z "$TEMP_FILE" ]]; then
        if [[ "$KEEP_TEMP" = true ]]; then
            TEMP_FILE="${INPUT_FILE}.temp"
        else
            TEMP_FILE="$(mktemp)"
        fi
    fi

    # Check if temporary file path is writable
    if ! touch "$TEMP_FILE" 2>/dev/null; then
        echo "Error: Cannot write to temporary file: $TEMP_FILE"
        exit 1
    fi

    # 3) decompress the input file into a temporary file
    if [[ "$DECOMP" != "raw" ]]; then
        "$DECOMP" -dk "$INPUT_FILE" || { echo "Error: Decompression failed"; exit 1; }
        # Get the decompressed file name (remove compression extension)
        DECOMP_FILE="${INPUT_FILE%.*}"
        mv "$DECOMP_FILE" "$TEMP_FILE" || { echo "Error: Failed to move decompressed file"; exit 1; }
    fi
    WORKING_FILE="$TEMP_FILE"
fi

# Check if working file exists and is writable
if ! touch "$WORKING_FILE" 2>/dev/null; then
    echo "Error: Cannot write to working file: $WORKING_FILE"
    exit 1
fi

# 4) mount the working file as a loop device with partition scanning
sudo losetup -P "$LOOP_DEVICE" "$WORKING_FILE" || { echo "Error: Failed to setup loop device"; exit 1; }

# 5) find out which partition is sfs
PART_INFO=""
# List all partitions
while read -r line; do
    if [[ $line =~ $LOOP_DEVICE ]]; then
        PARTITION="${LOOP_DEVICE}p${line##*$LOOP_DEVICE}"
        # Try to check if it's a squashfs partition
        if sudo unsquashfs -s "$PARTITION" &>/dev/null; then
            PART_INFO="$line"
            break
        fi
    fi
done < <(sudo fdisk -l "$LOOP_DEVICE" 2>/dev/null | grep "$LOOP_DEVICE")
if [[ -z "$PART_INFO" ]]; then
    echo "Error: No squashfs partition found in the image"
    sudo losetup -d "$LOOP_DEVICE"
    exit 1
fi

# 6) get partition size
# get partition number from $PARTITION (e.g. /dev/loop0p1 -> 1)
PART_NUM="${PARTITION##*p}"

# use parted to get start/end (bytes) and compute size
PART_SIZE_BYTES="$(sudo parted -s "$LOOP_DEVICE" unit B print 2>/dev/null | awk -v p="$PART_NUM" '
$1==p {
    s=$2; e=$3;
    sub(/B$/,"",s); sub(/B$/,"",e);
    s+=0; e+=0;
    print e - s;
    exit
}
')"

# fallback to fdisk-based calculation if parted failed
if [[ -z "$PART_SIZE_BYTES" ]]; then
        PART_SIZE_BYTES=$(echo "$PART_INFO" | awk '{print $4 * 512}')
fi

# 7) use unsquashfs to get the sfs filesystem size
FS_SIZE="$(sudo unsquashfs -s "$PARTITION" | grep -o 'Filesystem size [0-9]* bytes' | grep -o '[0-9][0-9]*')"
# if ROMSIZE is not specified, set it to FS_SIZE rounded up to nearest 8MiB unit. if ROMSIZE is specified and less than FS_SIZE. error out
if [[ -z "$ROMSIZE" ]]; then
    ROMSIZE=$(( (FS_SIZE + 8*1024*1024 - 1) / (8*1024*1024) * (8*1024*1024) ))
else
    ROMSIZE_BYTES=$(size_to_bytes "$ROMSIZE")
    if [[ -z "$ROMSIZE_BYTES" ]]; then
        echo "Error: Invalid rom size: $ROMSIZE"
        sudo losetup -d "$LOOP_DEVICE"
        exit 1
    fi
    if (( ROMSIZE_BYTES < FS_SIZE )); then
        echo "Error: Specified rom size ($ROMSIZE_BYTES bytes) is less than filesystem size ($FS_SIZE bytes)"
        sudo losetup -d "$LOOP_DEVICE"
        exit 1
    fi
    ROMSIZE="$ROMSIZE_BYTES"
fi

# 8) if ROMSIZE+OVERLAYSIZE > partition size, unmount loop device and use dd to add 0 bytes to the end of working file to expand it
OVERLAYSIZE_BYTES=$(size_to_bytes "$OVERLAYSIZE")
if [[ -z "$OVERLAYSIZE_BYTES" ]]; then
    echo "Error: Invalid overlay size: $OVERLAYSIZE"
    sudo losetup -d "$LOOP_DEVICE"
    exit 1
fi
TOTAL_SIZE_BYTES=$(( ROMSIZE_BYTES + OVERLAYSIZE_BYTES ))
if (( TOTAL_SIZE_BYTES > PART_SIZE_BYTES )); then
    # unmount loop device
    sudo losetup -d "$LOOP_DEVICE" || { echo "Error: Failed to detach loop device"; exit 1; }
    # expand working file
    dd if=/dev/zero bs=1 count=$(( TOTAL_SIZE_BYTES - PART_SIZE_BYTES )) >> "$WORKING_FILE" || { echo "Error: Failed to expand working file"; exit 1; }
    # remount loop device with partition scanning
    sudo losetup -P "$LOOP_DEVICE" "$WORKING_FILE" || { echo "Error: Failed to setup loop device"; exit 1; }
fi

# 9) unmount the loop device
sudo losetup -d "$LOOP_DEVICE" || { echo "Error: Failed to detach loop device"; exit 1; }

# 10) locate the hidden overlay filesystem
# (implementation depends on specific image structure)
FS_OFFSET="$(expr '(' "$FS_SIZE" + 65535 ')' / 65536 '*' 65536)" 

