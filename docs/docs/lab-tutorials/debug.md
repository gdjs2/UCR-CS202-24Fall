# Debugging Tips

## Before GDB

Before stepping into gdb, I would recommand print statement first. Always think about whether a single print statement can solve your problem before you decide to use gdb.

## Using GDB with QEMU

First, use command `make qemu-gdb` to compile and start qemu. 
```bash
$ make qemu-gdb
riscv64-linux-gnu-gcc -Wall -Werror -O -fno-omit-frame-pointer -ggdb -gdwarf-2 -MD -mcmodel=medany -fno-common -nostdlib
...
balloc: first 800 blocks have been allocated
balloc: write bitmap block at sector 45
*** Now run 'gdb' in another window.
qemu-system-riscv64 -machine virt -bios none -kernel kernel/kernel -m 128M -smp 3 -nographic -global virtio-mmio.force-legacy=false -drive file=fs.img,if=none,format=raw,id=x0 -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 -S -gdb tcp::25000
```

If you look at the `Makefile`, you can find the target definition at the end of file. 
```Makefile
K=kernel
U=user
...
qemu: $K/kernel fs.img
	$(QEMU) $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl-riscv
	sed "s/:1234/:$(GDBPORT)/" < $^ > $@

qemu-gdb: $K/kernel .gdbinit fs.img
	@echo "*** Now run 'gdb' in another window." 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)
```

The difference between `qemu` and `qemu-gdb` is that `qemu-gdb` will generate a gdb configuration file `.gdbinit`, which will be further read by gdb for initialization. Therefore, please run following `gdb-multiarch` (or `riscv64-linux-gnu-gdb` or `riscv64-unknown-elf-gdb`) under the same dicrectory so that they can find the initialization file. 

Run `gdb-multiarch` (or `riscv64-linux-gnu-gdb` or `riscv64-unknown-elf-gdb`) in another window **UNDER THE DIRECTORY OF XV6**. 

> If you start gdb and see a warning of the form 'warning: File "/home/xv6-riscv-UCR-CS202-Fall24/. gdbinit" auto-loading has been declined by ...', edit `~/.gdbinit` to add "add-auto-load-safe-path..." as suggected by the warning. 

```bash
$ gdb-multiarch 
GNU gdb (Ubuntu 15.0.50.20240403-0ubuntu1) 15.0.50.20240403-git
...
The target architecture is set to "riscv:rv64".
warning: No executable has been specified and target does not support
determining executable automatically.  Try using the "file" command.
0x0000000000001000 in ?? ()
(gdb) 
```

Afterwards, you can just use gdb as how you do for normal program.

For example, if we want to set breakpoint at line 137 of file `syscall.c`:
```bash
(gdb) b syscall.c:137
Breakpoint 1 at 0x8000283c: file kernel/syscall.c, line 137.
```

Then you can input `c` to continue the program and it will stop at the breakpoint set.
```bash
(gdb) c
Continuing.
[Switching to Thread 1.2]

Thread 2 hit Breakpoint 1, syscall () at kernel/syscall.c:137
137	  struct proc *p = myproc();
```

Refer to [MIT's sildes](https://pdos.csail.mit.edu/6.828/2019/lec/gdb_slides.pdf) about common-used gdb commands.

Some are listed below:

* `continue` or `c`, continue executing the program untill the next breakpoint or the end of program.
* `step` or `s`, execute the program by one step, if this is a function call, step into it.
* `next` or `n`, execute the program by one step without stepping into a function call.
* `finish`, execute to the end of function.
* `print <expression>` or `p <expression>`: print the value of expression.
* `display <expression>`: automatically display the value of expression whenever stop.
* `set <variable> = <value>` : modify the value of variable.
* `backtrace` or `bt`: show the call stack.
* `info frame`: show information about current frame.
* `info locals`: how all local variables for current frame.
* `list` or `l`: show the source code.
* `list <location>`: show the source code at specific location.