#!/bin/bash
set -eu

tmp_binary="shellcode"
tmp_dump="shellcode.dump"

cleanup() {
  rm -f "$tmp_binary" "$tmp_dump"
}

trap cleanup EXIT

gcc -m32 shellcode-creator.c -o "$tmp_binary" -O0 -fno-stack-protector -fno-pie -no-pie -g

objdump -d "$tmp_binary" > "$tmp_dump"

shellcode_bytes=$(
  awk '
    /<shellcode>:/ { in_shellcode=1; next }
    in_shellcode && /\tret/ { exit }
    in_shellcode {
      for (i = 2; i <= 7; i++) {
        if ($i ~ /^[0-9a-f][0-9a-f]$/) {
          printf "\\x%s", $i;
        }
      }
    }
  ' "$tmp_dump"
)

printf "%s\n" "$shellcode_bytes"

if printf "%s" "$shellcode_bytes" | grep -q '\\x00'; then
    echo -e "\nWARNING: There are still \\\x00 (null bytes) in this shellcode"
fi
