#!/usr/bin/env bash
# Build an additional harness without changing the official tests or Makefile.
set -euo pipefail
cd "$(dirname "$0")/.."
task_temp=$(mktemp -d /tmp/rubik-profile.XXXXXX)
prefix=${CROSS_COMPILE:-riscv-none-elf-}
make dump neg
for level in O1 O2 O3 Os; do
    "${prefix}gcc" "-$level" -march=rv32i_zicsr -mabi=ilp32 \
        -ffreestanding -fno-pic -fno-stack-protector -iquote . \
        -Icommon -Itests -c mytests/rubik_profile.c -o "$task_temp/profile.o"
    "${prefix}ld" -T common/linker.ld --no-warn-rwx-segments \
        -o "$task_temp/profile-$level.elf" "$task_temp/profile.o" \
        "build/rubik/$level/impl.o" build/rubik/impl_asm.o build/common/*.o
    third_party/rv32emu/build/rv32emu "$task_temp/profile-$level.elf" \
        | tee "results/rubik-profile-$level.log"
done
printf 'Additional harness artifacts: %s\n' "$task_temp"
