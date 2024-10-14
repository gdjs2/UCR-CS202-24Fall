# Lab 1 - System Call Implementation

## Before Start

[Xv6](https://pdos.csail.mit.edu/6.828/2012/xv6.html) is an open-source project built by MIT. It is a simple Unix-like OS for educational purpose. It has its source code published on Github and it is still maintained from time to time nowadays. In order to keep the consistency of the files you pull down, you are required to clone the XV6 files from our [forked repository](https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24). 

As you can notice to, we use a risc-v version of xv6 here. Most of modern laptops or PCs we use are based on X86-64 or ARM. Therefore, in order to run xv6, we need an emulator, which could provide a risc-v execution environment on our local machine. 

We would introduce some supplementary resources for you. Feel free to check them when you meet difficulties finishing your project. 

* [Debug for xv6](./debug.md)
* [xv6 Tutorial](https://pdos.csail.mit.edu/6.828/2024/)
* [xv6 Book](https://pdos.csail.mit.edu/6.828/2024/xv6/book-riscv-rev4.pdf)

## Compile & Boot

Before you start modifying the code, you need to know how to compile and run the code of xv6. As we introduced before, we need a risc-v [toolchain](https://en.wikipedia.org/wiki/Toolchain) to compile the source code and a [risc-v](https://en.wikipedia.org/wiki/RISC-V) emulator to provide the execution environment. 

Prior to stepping into installing the risc-v toolchain and emulator, we would suggest you finishing this project on a Unix-like environment, which includes all Linux distribution (e.g., Ubuntu, Arch, ...), macOS and so on. If you are using Windows, you can have a Linux subsystem running on your local machine though [Windows Subsystem Linux, WSL](https://learn.microsoft.com/en-us/windows/wsl/install). In order to fulfill the some virtualization requirements, you should try WSL 2 instead of WSL. 

We would provide the tested command line & instructions based on a Ubuntu 24.04. For other Linux distribution and macOS, please refer to your own Package Management System (like pacman for arch and brew for macOS) for issues you may meet.

### Tools

Run the following command in your command line:

#### Debian or Ubuntu
```bash
$ sudo apt-get install git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu 
```

#### Arch Linux
```bash
$ sudo pacman -S riscv64-linux-gnu-binutils riscv64-linux-gnu-gcc riscv64-linux-gnu-gdb qemu-emulators-full
```

#### macOS

Install developer tools if you haven't:
```bash
$ xcode-select --install
```

Next, install [Homebrew](https://brew.sh), a package manager for macOS if you haven't:
```bash
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Next, install the RISC-V compiler [toolchain](https://github.com/riscv-software-src/homebrew-riscv):
```bash
$ brew tap riscv/riscv
$ brew install riscv-tools
```

The brew formula may not link into /usr/local. You will need to update your shell's rc file (e.g. [~/.bashrc](https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html)) to add the appropriate directory to [$PATH](https://www.linfo.org/path_env_var.html).

Finally install QEMU:
```bash
$ brew install qemu
```

#### Testing your Installation

Run the following command to see whether it can give you the version number for the programs:
```bash
$ qemu-system-riscv64 --version
QEMU emulator version 8.2.2 (Debian 1:8.2.2+ds-0ubuntu1.2)
...
```

And at least one RISC-V version of GCC:
```bash
$ riscv64-linux-gnu-gcc --version
riscv64-linux-gnu-gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0
...
```
```bash
$ riscv64-unknown-elf-gcc --version
```
```bash
$ riscv64-unknown-linux-gnu-gcc --version
```

### Compile

Fetch the source code from [our xv6 repository](https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24):
```bash
$ git clone https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24.git
Cloning into 'xv6-riscv-UCR-CS202-Fall24'...
```

Change directory to the one containing xv6.
```bash
$ cd xv6-riscv-UCR-CS202-Fall24
```

Build and run xv6:
```bash
$ make qemu
riscv64-linux-gnu-gcc    -c -o kernel/entry.o kernel/entry.S
riscv64-linux-gnu-gcc -Wall -Werror -O -fno-omit-frame-pointer -ggdb
...
riscv64-linux-gnu-objdump -S user/_zombie > user/zombie.asm
riscv64-linux-gnu-objdump -t user/_zombie | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$/d' > user/zombie.sym
mkfs/mkfs fs.img README user/_cat user/_echo user/_forktest user/_grep user/_init user/_kill user/_ln user/_ls user/_mkdir user/_rm user/_sh user/_stressfs user/_usertests user/_grind user/_wc user/_zombie 
nmeta 46 (boot, super, log blocks 30 inode blocks 13, bitmap blocks 1) blocks 1954 total 2000
balloc: first 767 blocks have been allocated
balloc: write bitmap block at sector 45
qemu-system-riscv64 -machine virt -bios none -kernel kernel/kernel -m 128M -smp 3 -nographic -global virtio-mmio.force-legacy=false -drive file=fs.img,if=none,format=raw,id=x0 -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

xv6 kernel is booting

hart 2 starting
hart 1 starting
init: starting sh
$ 
```

Now, xv6-riscv has been compiled and a bash is running. If you type `ls` at the prompt, you should see output similar to the following:
```bash
$ ls
.              1 1 1024
..             1 1 1024
README         2 2 2292
cat            2 3 34264
echo           2 4 33184
forktest       2 5 16184
grep           2 6 37520
init           2 7 33648
kill           2 8 33104
ln             2 9 32920
ls             2 10 36288
mkdir          2 11 33160
rm             2 12 33152
sh             2 13 54728
stressfs       2 14 34048
usertests      2 15 179352
grind          2 16 49400
wc             2 17 35216
zombie         2 18 32528
console        3 19 0

```

There are the files that mkfs includes in the initial file system; most are programs you can run. 

To quit qemu type `Ctrl-a x` (press `Ctrl` and `a` at the same time, followed by `x`)

**Tips**: Print state is always a very powerful tool to debug. But if you truly prefer gdb, please refer to [here](https://pdos.csail.mit.edu/6.828/2024/labs/guidance.html) and *Using gdb section* of [here](https://pdos.csail.mit.edu/6.828/2024/labs/syscall.html). 

## Primary Instruction

We would like to divide the instruction for our lab into two levels-Primary and Advanced. You can choose primary one if you want to challenge yourself. The primary instruction will tell you what you need to do and where to find corresponding information. The advanced one, instead, is more like a step-by-step instruction to help you go towards the goal.

I'd highly encourage you using primary first and go for the advanced instruction if you can't figure it out by yourself.

1. Read section 4.3 and 4.4 of [xv6 book](https://pdos.csail.mit.edu/6.828/2024/xv6/book-riscv-rev4.pdf).
2. Define your customized syscall and its number in `kernel/syscall.h`.
3. Define corresponding prototype for kernel space function in `kernel/syscall.c`.
4. Add the mapping relationship between the syscall number and kernel space function in `syscalls` map of `kernel/syscall.c`.
5. Implement your system call function in `kernel/sysproc.c`.
6. Modify `usys.pl` script, which will generate `usys.S` containing the system call stubs under user space. 
7. Add user space syscall prototype in `user/user.h`.
8. Write a user space program to show your result.

## Advanced Instruction

### Read Section 4.3 and 4.4!!

Read these two sections from [xv6 book](https://pdos.csail.mit.edu/6.828/2024/xv6/book-riscv-rev4.pdf) to help you write report!

### Modification in Kernel Space

#### Define SYSCALL and Number

Append single line to `kernel/syscall.h`, which defines the syscall name and syscall number (you can choose any vacant number, I just randomly choose 33 here. Don't choose the one same with me, or I would assume you just copy the code from the instruction).

```c
// System call numbers
#define SYS_fork    1
#define SYS_exit    2
...
#define SYS_close   21
#define SYS_info    33
```

#### Define Kernel Space Prototype

In `kernel/syscall.c`, find comment about *prototypes for the functions...* and append one function prototype for your system call to this code section. 
```c
// Prototypes for the functions that handle system calls.
extern uint64 sys_fork(void);
extern uint64 sys_exit(void);
...
extern uint64 sys_close(void);
extern uint64 sys_info(void);
```

Several questions:
1. Should this function must be named as `sys_info()`?
2. Why the parameters defined here is `void` instead of `int`?
3. What is extern function in C program?

#### Add a Mapping between SYSCALL# and Prototype

In order to tell the OS, which function should be called when you meet specific syscall number, we need to add a mapping between the number and the function prototype. This mapping information is encoded in a static-generated array. We need to insert the address of function into the slot in the array indexed by the syscall number.

Search for comment *An array mapping syscall numbers from syscall.h* in `kernel/syscall.c` and insert one element into this array.
```c
// An array mapping syscall numbers from syscall.h
// to the function that handles the system call.
static uint64 (*syscalls[])(void) = {
[SYS_fork]    sys_fork,
[SYS_exit]    sys_exit,
[SYS_wait]    sys_wait,
...
[SYS_close]   sys_close,
[SYS_info]    sys_info,
};
```

#### Implement SYSCALL

You can check existing implemented syscalls from `kernel/sysproc.c` and what you need to do is implementing your customized syscall function here. 

The way you get arguments in syscall function is different from the regular way in C/C++ program (directly from certain offset to stack/base pointer and heap). You can refer to existing function implementation about how to retrieve the arguments. 

Also, you may need to modify exist structures or functions to help you implement your syscall. 

### Modification in User Space
#### Modify `usys.pl`

`usys.pl` is responsible for generating `usys.S`, which contains all syscall stubs in user space. Therefore, we need to add our customized syscall into this script as well.

```perl
entry("fork");
...
entry("info");
```

#### Add User Space Prototype

We need to add a function prototype in user space for program to call the syscall. They are at `user/user.h`.

Under the syscall section in this file, append your prototype:
```c
// system calls
int fork(void);
...
int uptime(void);
int info(int)
```

#### User Space Program

Finally, you may need a user space program to help you check your syscall implementation. 

We provide a simple version here:
```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main() {
    printf("Total number of system calls made by current process: %d\n", info(2));
    printf("Total number of processes: %d\n", info(1));
    printf("Total number of system calls made by current process: %d\n", info(2));
    printf("Total number of memory pages used by current process: %d\n", info(3));
    printf("Total number of system calls made by current process: %d\n", info(2));
    exit(0);
}
```

You need to put this source file under `/user/`. Assume you have this code stored as file `test_info.c` under `/user` and you need to futher add this file into the `makefile`, which tells which files should be compiled. 

In `Makefile`, find variable `UPROGS` and append our user space program to it.
```makefile
UPROGS=\
	$U/_cat\
	$U/_echo\
	$U/_forktest\
...
	$U/_zombie\
	$U/_test_info\
```

Now you can recompile the xv6 and run the program `test_info` in the bash.
```sh
$ ./test_info
Total number of system calls made by current process: 3
Total number of processes: 3
Total number of system calls made by current process: 90
Total number of memory pages used by current process: 4
Total number of system calls made by current process: 205
```

Please include a screenshot and explanation of execution result in your report.