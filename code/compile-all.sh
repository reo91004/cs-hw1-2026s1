#!/bin/bash
set -eu

FLAGS="-m32 -O0 -fno-stack-protector -z execstack -fno-pie -no-pie -g"
SAFE_FLAGS="-m32 -O0 -fno-stack-protector -fno-pie -no-pie -g"

if ! gcc -m32 -x c - -o /tmp/overflow_with_joy_m32_test >/dev/null 2>&1 <<'EOF'
int main(void) { return 0; }
EOF
then
  echo "32-bit toolchain is not available. Install gcc-multilib and libc6-dev-i386 first." >&2
  exit 1
fi
rm -f /tmp/overflow_with_joy_m32_test

if [ -w /proc/sys/kernel/randomize_va_space ]; then
  echo 0 > /proc/sys/kernel/randomize_va_space
else
  echo "ASLR is still enabled. Disable it manually if you want stable stack addresses." >&2
fi

gcc shellcode-creator.c -o shellcode $SAFE_FLAGS

gcc hackme1.c -o hackme1 $FLAGS
gcc hackme2.c -o hackme2 $FLAGS
gcc hackme3.c -o hackme3 $FLAGS
# gcc hackme4.c -o hackme4 $FLAGS
# gcc hackme5.c -o hackme5 $FLAGS
gcc hackme6.c -o hackme6 $FLAGS

gcc exploit1.c -o exploit1 $FLAGS
gcc exploit2.c -o exploit2 $FLAGS
gcc exploit3.c -o exploit3 $FLAGS
# gcc exploit4.c -o exploit4 $FLAGS
# gcc exploit5.c -o exploit5 $FLAGS
gcc exploit6.c -o exploit6 $FLAGS
