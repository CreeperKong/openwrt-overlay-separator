#!/bin/bash

# Default values
DECOMP="auto"
COMP=""
ROMSIZE=""
OVERLAYSIZE=""
OVERLAY_FS="ext4"
KEEP_TEMP=false
TEMP_FILE=""
RAW_MODE=false
WORKING_FILE=""
SILENT_MODE=false
POS_COUNT=0

# Help function
usage() {
    echo "Usage: $0 [options] <input file> <output file>"
    echo "Options:"
    echo "  -d <program>         Decompression program (auto detect by default)"
    echo "                       Use 'raw' to process uncompressed file"
    echo "  -c <program>         Compression program (default: same as decompression)"
    echo "                       Use 'raw' to skip compression"
    echo "  -k                   Keep temporary files"
    echo "  -t <file>            Specify temporary file path"
    echo "  -s                   Non-interactive"
    echo "  --rom-size <size>    Size of /rom partition"
    echo "                       (default: sfs size rounded up to nearest 8MiB)"
    echo "  --overlay-size <size> Size of /overlay partition (default: 128MiB)"
    echo "  --overlay-filesystem <fs> Filesystem for overlay (default: ext4, alt: f2fs)"
    echo "  -h, --help           Show this help message"
    exit 0
}

# Output function
output() {
    if [[ "$SILENT_MODE" = false ]]; then
        echo "$1"
    fi
}

# Add: size parsing function (recognize K KiB, M MiB, G GiB, case-insensitive)
size_to_bytes() {
    local v="$1"
    if [[ -z "$v" ]]; then
        echo ""
        return
    fi
    # remove spaces
    v="${v//[[:space:]]/}"
    # match number + optional unit
    if [[ $v =~ ^([0-9]+(\.[0-9]+)?)([A-Za-z]+)?$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[3]}"
        unit="${unit,,}"  # lowercase
        case "$unit" in
            k|kb|kib)
                awk "BEGIN{printf \"%0.f\", $num * 1024}"
                ;;
            m|mb|mib)
                awk "BEGIN{printf \"%0.f\", $num * 1024 * 1024}"
                ;;
            g|gb|gib)
                awk "BEGIN{printf \"%0.f\", $num * 1024 * 1024 * 1024}"
                ;;
            "" )
                # plain bytes (integer or decimal)
                awk "BEGIN{printf \"%0.f\", $num}"
                ;;
            *)
                echo ""
                ;;
        esac
    else
        echo ""
    fi
}

# Interactive prompt function (English)
interactive_prompt() {
    echo "Welcome to OpenWrt Overlay Separator!"
    # Only ask for values that are not already provided via parameters
    if [[ -z "$INPUT_FILE" ]]; then
        read -p "Enter input file path: " INPUT_FILE
    fi
    if [[ -z "$OUTPUT_FILE" ]]; then
        read -p "Enter output file path: " OUTPUT_FILE
    fi
    if [[ -z "$OVERLAYSIZE" ]]; then
        # default overlay size 128MiB if user presses Enter
        read -p "Enter overlay size (e.g. 128MiB) [128MiB]: " _tmp
        OVERLAYSIZE=${_tmp:-128MiB}
    fi
    if [[ -z "$ROMSIZE" ]]; then
        # empty means auto
        read -p "Enter ROM size (optional, press Enter to auto) [auto]: " _tmp
        if [[ -n "$_tmp" ]]; then
            ROMSIZE="$_tmp"
        else
            ROMSIZE=""
        fi
    fi
    # Only ask for overlay fs if not provided
    if [[ -z "$OVERLAY_FS" ]]; then
        read -p "Choose overlay filesystem (ext4/f2fs) [ext4]: " _tmp
        OVERLAY_FS=${_tmp:-ext4}
    fi
    if [[ "$OVERLAY_FS" != "ext4" && "$OVERLAY_FS" != "f2fs" ]]; then
        echo "Error: Overlay filesystem must be either ext4 or f2fs"
        exit 1
    fi
    # Ask about KEEP_TEMP only if it wasn't enabled via params
    if [[ "$KEEP_TEMP" != true ]]; then
        read -p "Keep temporary files? (y/N) [N]: " _tmp
        _tmp=${_tmp:-N}
        [[ "$_tmp" =~ ^[Yy]$ ]] && KEEP_TEMP=true
    fi
    # Do not prompt about silent mode here (non-interactive is -s and should prevent prompts)
}

# Parse command line arguments
# (previous behavior: interactive only when no args; new: always parse args, then prompt for missing)
if [[ $# -gt 0 ]]; then
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
            -s)
                SILENT_MODE=true
                shift
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
                    output "Error: Overlay filesystem must be either ext4 or f2fs"
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
                    POS_COUNT=$((POS_COUNT+1))
                elif [[ -z "$OUTPUT_FILE" ]]; then
                    OUTPUT_FILE="$1"
                    POS_COUNT=$((POS_COUNT+1))
                else
                    output "Error: Too many arguments"
                    usage
                fi
                shift
                ;;
        esac
    done
fi

# Set default TEMP_FILE if not specified and needed
if [[ -z "$TEMP_FILE" && "$COMP" != "raw" ]]; then
    TEMP_FILE="/tmp/openwrt-separator-$$.img"
fi

# If exactly one file name was provided as positional argument, show usage and exit
if [[ "$POS_COUNT" -eq 1 ]]; then
    usage
fi

# After parsing args, if required values are missing and not in non-interactive mode, prompt interactively.
if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" || -z "$OVERLAYSIZE" ]]; then
    if [[ "$SILENT_MODE" = false ]]; then
        interactive_prompt
    else
        output "Error: Missing required parameters and non-interactive mode enabled"
        usage
    fi
fi

# Validate required arguments
if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
    output "Error: Input and output files are required"
    usage
fi

# OVERLAYSIZE is required
if [[ -z "$OVERLAYSIZE" ]]; then
    output "Error: --overlay-size is required"
    usage
fi

# If compression program is not specified, use the same as decompression
if [[ -z "$COMP" ]]; then
    COMP="$DECOMP"
fi

# Auto-detect compression if DECOMP is "auto"
if [[ "$DECOMP" == "auto" ]]; then
    detected="unknown"
    if file "$INPUT_FILE" | grep -q "gzip compressed"; then
        detected="gzip"
    elif file "$INPUT_FILE" | grep -q "XZ compressed"; then
        detected="xz"
    elif file "$INPUT_FILE" | grep -q "bzip2 compressed"; then
        detected="bzip2"
    elif file "$INPUT_FILE" | grep -q "Zstandard compressed"; then
        detected="zstd"
    fi

    if [[ "$SILENT_MODE" = false ]]; then
        # Interactive: show detected and allow override (only if user didn't provide DECOMP via args)
        if [[ "$detected" == "unknown" ]]; then
            read -p "Compression format could not be auto-detected. Choose decompression program (gzip/xz/bzip2/zstd/raw): " user_decomp
            if [[ -n "$user_decomp" ]]; then
                DECOMP="$user_decomp"
            else
                output "Error: No decompression program chosen"
                exit 1
            fi
        else
            read -p "Detected compression: $detected. Use this for decompression? (default: $detected) " ans_decomp
            if [[ -n "$ans_decomp" ]]; then
                DECOMP="$ans_decomp"
            else
                DECOMP="$detected"
            fi
        fi

        # Ask for compression program for output if not already specified
        read -p "Choose compression program for output (gzip/xz/bzip2/zstd/raw) [default: $DECOMP]: " user_comp
        if [[ -n "$user_comp" ]]; then
            COMP="$user_comp"
        else
            COMP="$DECOMP"
        fi
    else
        # Non-interactive: require detection to succeed
        if [[ "$detected" == "unknown" ]]; then
            output "Error: Unable to detect compression format"
            exit 1
        fi
        DECOMP="$detected"
        [[ -z "$COMP" ]] && COMP="$detected"
    fi
fi

# Validate compression/decompression programs
case "$DECOMP" in
    "gzip"|"xz"|"bzip2"|"zstd"|"raw")
        ;;
    *)
        output "Error: Unsupported decompression program: $DECOMP"
        exit 1
        ;;
esac

# Validate compression program
case "$COMP" in
    "gzip"|"xz"|"bzip2"|"zstd"|"raw")
        ;;
    *)
        output "Error: Unsupported compression program: $COMP"
        exit 1
        ;;
esac

# 1) lookup an unused loop device, if not found, exit with error
output "Looking for available loop device..."
LOOP_DEVICE=$(losetup -f)
if [[ -z "$LOOP_DEVICE" ]]; then
    output "Error: No unused loop device found"
    exit 1
fi
output "Found loop device: $LOOP_DEVICE"

# 2) prepare file handling
if [[ "$COMP" = "raw" ]]; then
    # When compression is raw, decompress directly to output file and work on that
    # 3) decompress the input file into the output file
    if [[ "$DECOMP" = "raw" ]]; then
        # Both input and output are raw, just copy
        if ! cp "$INPUT_FILE" "$OUTPUT_FILE"; then
            output "Error: Cannot copy input file to output file: $OUTPUT_FILE"
            exit 1
        fi
    else
        # Decompress to output file, ignoring trailing garbage warnings
        case "$DECOMP" in
            gzip)
                gzip -dc "$INPUT_FILE" > "$OUTPUT_FILE" || { output "Error: Decompression failed"; exit 1; }
                ;;
            xz)
                xz -dc "$INPUT_FILE" > "$OUTPUT_FILE" || { output "Error: Decompression failed"; exit 1; }
                ;;
            bzip2)
                bzip2 -dc "$INPUT_FILE" > "$OUTPUT_FILE" || { output "Error: Decompression failed"; exit 1; }
                ;;
            zstd)
                zstd -dc "$INPUT_FILE" > "$OUTPUT_FILE" || { output "Error: Decompression failed"; exit 1; }
                ;;
            *)
                "$DECOMP" -dk "$INPUT_FILE" || { output "Error: Decompression failed"; exit 1; }
                DECOMP_FILE="${INPUT_FILE%.*}"
                mv "$DECOMP_FILE" "$OUTPUT_FILE" || { output "Error: Failed to move decompressed file"; exit 1; }
                ;;
        esac
    fi
    WORKING_FILE="$OUTPUT_FILE"
else
    # Normal mode with temporary file handling in /tmp
    # 3) decompress the input file into a temporary file
    if [[ "$DECOMP" != "raw" ]]; then
        case "$DECOMP" in
            gzip)
                gzip -dc "$INPUT_FILE" > "$TEMP_FILE" || { output "Warning: Decompression had errors"; }
                ;;
            xz)
                xz -dc "$INPUT_FILE" > "$TEMP_FILE" || { output "Warning: Decompression had errors"; }
                ;;
            bzip2)
                bzip2 -dc "$INPUT_FILE" > "$TEMP_FILE" || { output "Warning: Decompression had errors"; }
                ;;
            zstd)
                zstd -dc "$INPUT_FILE" > "$TEMP_FILE" || { output "Warning: Decompression had errors"; }
                ;;
        esac
    else
        # DECOMP is raw, copy input to temp file
        if ! cp "$INPUT_FILE" "$TEMP_FILE"; then
            output "Error: Cannot copy input file to temp file: $TEMP_FILE"
            exit 1
        fi
    fi
    WORKING_FILE="$TEMP_FILE"
fi

# Check if working file exists and is writable
if ! touch "$WORKING_FILE" 2>/dev/null; then
    output "Error: Cannot write to working file: $WORKING_FILE"
    exit 1
fi

# 4) mount the working file as a loop device with partition scanning
output "Setting up loop device $LOOP_DEVICE for $WORKING_FILE..."
if ! sudo losetup -v -P "$LOOP_DEVICE" "$WORKING_FILE"; then
    output "Error: Failed to setup loop device"
    output "Loop device: $LOOP_DEVICE"
    output "Working file: $WORKING_FILE"
    exit 1
fi
output "Loop device setup successful"

# 5) find out which partition is sfs
PART_INFO=""
PARTITION=""
# List all partitions and find squashfs
while read -r part; do
    # Try to check if it's a squashfs partition
    if sudo unsquashfs -s "$part" &>/dev/null; then
        PARTITION="$part"
        # Extract the partition number from the device name
        PART_NUM="${part##*p}"
        # Get the corresponding line from fdisk for this partition
        PART_INFO=$(sudo fdisk -l "$LOOP_DEVICE" 2>/dev/null | grep "${LOOP_DEVICE}p${PART_NUM}")
        break
    fi
done < <(ls "${LOOP_DEVICE}"p* 2>/dev/null)

if [[ -z "$PARTITION" ]]; then
    output "Error: No squashfs partition found in the image"
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
    ROMSIZE_BYTES=$(( (FS_SIZE + 8*1024*1024 - 1) / (8*1024*1024) * (8*1024*1024) ))
    ROMSIZE="$ROMSIZE_BYTES"
else
    ROMSIZE_BYTES=$(size_to_bytes "$ROMSIZE")
    if [[ -z "$ROMSIZE_BYTES" ]]; then
        output "Error: Invalid rom size: $ROMSIZE"
        sudo losetup -d "$LOOP_DEVICE"
        exit 1
    fi
    if (( ROMSIZE_BYTES < FS_SIZE )); then
        output "Error: Specified rom size ($ROMSIZE_BYTES bytes) is less than filesystem size ($FS_SIZE bytes)"
        sudo losetup -d "$LOOP_DEVICE"
        exit 1
    fi
    ROMSIZE="$ROMSIZE_BYTES"
fi
FS_OFFSET="$(expr '(' "$FS_SIZE" + 65535 ')' / 65536 '*' 65536)"

# 8) if ROMSIZE+OVERLAYSIZE > partition size, unmount loop device and use dd to add 0 bytes to the end of working file to expand it
OVERLAYSIZE_BYTES=$(size_to_bytes "$OVERLAYSIZE")
if [[ -z "$OVERLAYSIZE_BYTES" ]]; then
    output "Error: Invalid overlay size: $OVERLAYSIZE"
    sudo losetup -d "$LOOP_DEVICE"
    exit 1
fi
TOTAL_SIZE_BYTES=$(( ROMSIZE_BYTES + OVERLAYSIZE_BYTES ))
if (( TOTAL_SIZE_BYTES > PART_SIZE_BYTES )); then
    # unmount loop device
    output "Detaching loop device for expansion..."
    if ! sudo losetup -v -d "$LOOP_DEVICE"; then
        output "Error: Failed to detach loop device"
        exit 1
    fi
    output "Loop device detached"
    
    # expand working file (round up to 512-byte boundary)
    EXPAND_SIZE=$(( TOTAL_SIZE_BYTES - PART_SIZE_BYTES ))
    EXPAND_SIZE_ALIGNED=$(( (EXPAND_SIZE + 511) / 512 * 512 ))
    output "Expanding working file by $EXPAND_SIZE_ALIGNED bytes..."
    dd if=/dev/zero bs=512 count=$(( EXPAND_SIZE_ALIGNED / 512 )) >> "$WORKING_FILE" || { output "Error: Failed to expand working file"; exit 1; }
    
    # lookup an unused loop device again
    output "Looking for available loop device after expansion..."
    LOOP_DEVICE=$(losetup -f)
    if [[ -z "$LOOP_DEVICE" ]]; then
        output "Error: No unused loop device found"
        exit 1
    fi
    output "Found loop device: $LOOP_DEVICE"
    
    # remount loop device with partition scanning
    output "Remounting loop device after expansion..."
    if ! sudo losetup -v -P "$LOOP_DEVICE" "$WORKING_FILE"; then
        output "Error: Failed to setup loop device after expansion"
        output "Loop device: $LOOP_DEVICE"
        output "Working file: $WORKING_FILE"
        exit 1
    fi
    output "Loop device remounted successfully"
fi

# 10) delete the partition and recreate it with new size at the same starting offset
PART_START_BYTES="$(sudo parted -s "$LOOP_DEVICE" unit B print 2>/dev/null | awk -v p="$PART_NUM" '
$1==p {
    s=$2;
    sub(/B$/,"",s);
    s+=0;
    print s;
    exit
}
')"
if [[ -z "$PART_START_BYTES" ]]; then
    output "Error: Failed to get partition start offset"
    sudo losetup -d "$LOOP_DEVICE"
    exit 1
fi
sudo parted -s "$LOOP_DEVICE" rm "$PART_NUM" || { output "Error: Failed to delete partition"; exit 1; }
PART_END_BYTES=$(( PART_START_BYTES + ROMSIZE_BYTES ))
sudo parted -s "$LOOP_DEVICE" mkpart primary "$PART_START_BYTES"B "$PART_END_BYTES"B || { output "Error: Failed to create new partition"; exit 1; }

# 11) use dd to write zeroes to fill up the rest part of the squashfs partition according to FS_OFFSET using loop partition (optional, but good for f2fs)
SQUASHFS_PARTITION="${LOOP_DEVICE}p${PART_NUM}"
CURRENT_SQUASHFS_SIZE_BYTES="$(sudo blockdev --getsize64 "$SQUASHFS_PARTITION")"
# Overwrite the rest of the squashfs partition (outside sfs data) with zeroes for better compression
if (( FS_OFFSET < CURRENT_SQUASHFS_SIZE_BYTES )); then
    ZERO_START=$FS_OFFSET
    ZERO_COUNT=$(( CURRENT_SQUASHFS_SIZE_BYTES - FS_OFFSET ))
    sudo dd if=/dev/zero of="$SQUASHFS_PARTITION" bs=1 seek=$ZERO_START count=$ZERO_COUNT conv=notrunc status=none || { output "Error: Failed to zero squashfs partition tail"; exit 1; }
fi

# 12) create overlay partition with the size specified in $OVERLAYSIZE and save the partition block to $OVERLAY_PARTITION
# get current partition layout with sfdisk -d and save all used partition number to a variable
PART_NUMBERS=$(sudo sfdisk -d "$LOOP_DEVICE" 2>/dev/null | awk '/^\/dev\/loop/ {print $1}' | sed 's/.*p//' | paste -sd,)

# Calculate overlay partition start with proper alignment (2048 sectors = 1MiB)
# Start after the previous partition end, aligned to 2048 sectors (1MiB boundary)
SECTOR_SIZE=512
ALIGNMENT_SECTORS=2048
ALIGNMENT_BYTES=$((ALIGNMENT_SECTORS * SECTOR_SIZE))

# Calculate start position aligned to 1MiB boundary
OVERLAY_START_BYTES=$(( ((PART_END_BYTES + ALIGNMENT_BYTES ) / ALIGNMENT_BYTES) * ALIGNMENT_BYTES ))
OVERLAY_END_BYTES=$(( OVERLAY_START_BYTES + OVERLAYSIZE_BYTES - 4096 ))

sudo parted -s "$LOOP_DEVICE" mkpart primary "$OVERLAY_START_BYTES"B "$OVERLAY_END_BYTES"B || { output "Error: Failed to create overlay partition"; exit 1; }
# sfdisk -d again to find out the number of the newly created partition which is not in PART_NUMBERS
NEW_PART_NUMBERS=$(sudo sfdisk -d "$LOOP_DEVICE" 2>/dev/null | awk '/^\/dev\/loop/ {print $1}' | sed 's/.*p//' | paste -sd,)
# Find the new partition number
for num in $(echo "$NEW_PART_NUMBERS" | tr ',' ' '); do
    if ! echo ",$PART_NUMBERS," | grep -q ",$num,"; then
        NEW_PART_NUM="$num"
        break
    fi
done
if [[ -z "$NEW_PART_NUM" ]]; then
    output "Error: Failed to determine new overlay partition number"
    sudo losetup -d "$LOOP_DEVICE"
    exit 1
fi

OVERLAY_PARTITION="${LOOP_DEVICE}p${NEW_PART_NUM}"

# 13) format overlay partition with specified filesystem
if [[ "$OVERLAY_FS" == "ext4" ]]; then
    sudo mkfs.ext4 -F -L rootfs_data "$OVERLAY_PARTITION" || { output "Error: Failed to format overlay partition"; sudo losetup -d "$LOOP_DEVICE"; exit 1; }
else
    sudo mkfs.f2fs -f -l rootfs_data "$OVERLAY_PARTITION" || { output "Error: Failed to format overlay partition"; sudo losetup -d "$LOOP_DEVICE"; exit 1; }
fi

# 14) unmount the loop device
output "Detaching loop device..."
if ! sudo losetup -v -d "$LOOP_DEVICE"; then
    output "Error: Failed to detach loop device"
    output "Loop device: $LOOP_DEVICE"
    exit 1
fi
output "Loop device detached successfully"

# 15) compress the working file to output file if compression is not raw
if [[ "$COMP" != "raw" ]]; then
    output "Compressing output file..."
    
    case "$COMP" in
        "gzip")
            gzip -c "$WORKING_FILE" > "$OUTPUT_FILE" || { output "Error: Compression failed"; exit 1; }
            ;;
        "xz")
            xz -c "$WORKING_FILE" > "$OUTPUT_FILE" || { output "Error: Compression failed"; exit 1; }
            ;;
        "bzip2")
            bzip2 -c "$WORKING_FILE" > "$OUTPUT_FILE" || { output "Error: Compression failed"; exit 1; }
            ;;
        "zstd")
            zstd -c "$WORKING_FILE" > "$OUTPUT_FILE" || { output "Error: Compression failed"; exit 1; }
            ;;
    esac
    
    # Clean up temp file if not keeping it
    if [[ "$KEEP_TEMP" != true ]]; then
        rm -f "$WORKING_FILE"
    fi
else
    # When COMP is raw, working file IS the output file, no compression or cleanup needed
    output "Output file ready (no compression): $OUTPUT_FILE"
fi

echo "Done! Output file: $OUTPUT_FILE"