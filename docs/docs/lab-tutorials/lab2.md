# Lab 2 - Scheduler, Lottery and Stride

## Before Start

Take a look at [our project repo](https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24). We have a new [scheduler-lab branch](https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24/tree/scheduler-lab) published. In this lab, you need implement your work based on this branch. 

Also, get overall idea for these two scheduling strategy:
* [Lottery Scheduling](https://dl.acm.org/doi/pdf/10.5555/1267638.1267639)
* [Stride Scheduling](https://web.eecs.umich.edu/~prabal/teaching/eecs582-w13/readings/stride.pdf)

## Pull the Repo

Clone the repo to your local machine. 
```bash
$ git clone https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24.git
```

Change directory and checkout to scheduler-lab branch. 
```bash
$ git checkout scheduler-lab
```

If you receive error like:
```bash
fatal: detected dubious ownership in repository at...
```
just follow the instruction mark the directory as safe. 

Let's first see what has been done for our project.

### Makefile

In `Makefile`, we have four mofidifcations:
1. Add a source file and objective file random.o, which is a [Linear congruential generator (LCG)](https://en.wikipedia.org/wiki/Linear_congruential_generator) for generating random numbers in lottery scheduler.
2. Add a macro deciding which scheduler to use in compiling.
3. Add a user space program to test different schedulers.
4. Change the cpu counts to one. (why we need do this?)

```diff
diff --git a/Makefile b/Makefile
index b2ce8c0..f8c820e 100644
--- a/Makefile
+++ b/Makefile
@@ -28,8 +28,7 @@ OBJS = \
   $K/sysfile.o \
   $K/kernelvec.o \
   $K/plic.o \
-  $K/virtio_disk.o \
-  $K/random.o
+  $K/virtio_disk.o
 
 # riscv64-unknown-elf- or riscv64-linux-gnu-
 # perhaps in /opt/riscv/bin
@@ -79,13 +78,6 @@ ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
 CFLAGS += -fno-pie -nopie
 endif
 
-# Add lottery and stride scheduler
-ifeq ($(SCHEDULER), LOTTERY)
-	CFLAGS += -DSCHEDULER=LOTTERY
-else ifeq ($(SCHEDULER), STRIDE)
-	CFLAGS += -DSCHEDULER=STRIDE
-endif
-
 LDFLAGS = -z max-page-size=4096
 
 $K/kernel: $(OBJS) $K/kernel.ld $U/initcode
@@ -147,7 +139,6 @@ UPROGS=\
 	$U/_grind\
 	$U/_wc\
 	$U/_zombie\
-	$U/_test_scheduler\
 
 fs.img: mkfs/mkfs README $(UPROGS)
 	mkfs/mkfs fs.img README $(UPROGS)
@@ -169,7 +160,7 @@ QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
 	then echo "-gdb tcp::$(GDBPORT)"; \
 	else echo "-s -p $(GDBPORT)"; fi)
 ifndef CPUS
-CPUS := 1
+CPUS := 3
 endif
 
 QEMUOPTS = -machine virt -bios none -kernel $K/kernel -m 128M -smp $(CPUS) -nographic
```

### /kernel/defs.h

In `/kernel/defs.h`, we have two modifications:
1. Add declaration for two kernel functions. `void proc_set_tickets(int)` is for setting tickets for current process and `int getticks(int pid)` is for getting ticks spent on particular process specified by `pid`.
2. Add function interfaces for `random.o`-`uint random(void)` for generating random numbers and `void srand(uint64)` for specifying the seed of randomization. 

```diff
diff --git a/kernel/defs.h b/kernel/defs.h
index 03b3d6c..d1b6bb9 100644
--- a/kernel/defs.h
+++ b/kernel/defs.h
@@ -106,8 +106,6 @@ void            yield(void);
 int             either_copyout(int user_dst, uint64 dst, void *src, uint64 len);
 int             either_copyin(void *dst, int user_src, uint64 src, uint64 len);
 void            procdump(void);
-void            proc_set_tickets(int);
-int             getticks(int pid);
 
 // swtch.S
 void            swtch(struct context*, struct context*);
@@ -189,7 +187,3 @@ void            virtio_disk_intr(void);
 
 // number of elements in fixed-size array
 #define NELEM(x) (sizeof(x)/sizeof((x)[0]))
-
-// random.c
-uint            random(void);
-void            srand(uint64);
\ No newline at end of file
```

### /kernel/param.h

In `/kernel/param.h`, we defined several constants for schedulers:
1. `STRIDE1`: the total stride in stride scheduler, $2^{16}$ by default
2. `DEFAULT_TICKS`: the default **TICKETS** for process, $2^{10}=1024$ by default.
3. `LOTTERY` and `STRIDE`: variables for conditional compilation.

```diff
diff --git a/kernel/param.h b/kernel/param.h
index f998f5d..80ec6d3 100644
--- a/kernel/param.h
+++ b/kernel/param.h
@@ -12,7 +12,4 @@
 #define FSSIZE       2000  // size of file system in blocks
 #define MAXPATH      128   // maximum file path name
 #define USERSTACK    1     // user stack pages
-#define STRIDE1      (1<<16)     // stride value for stride scheduling
-#define DEFAULT_TICKS (1<<10) // default time slice for stride scheduling
-#define LOTTERY      1 // lottery scheduling
-#define STRIDE       2 // stride scheduling
+
```

### /kernel/proc.c

This is the most complex part and what you need to do is implementing two scheduler functions in this file, referring to **TODO** symbols. 

#### New Member Vars

We have four member variables defined in `struct proc` for schedulers-`tickets`, `stride`, `pass` and `ticks`. For their definition and usage, refer to the [papers](#before-start). 
```diff
index 88ef59c..130d9ce 100644
--- a/kernel/proc.c
+++ b/kernel/proc.c
@@ -124,10 +124,6 @@ allocproc(void)
 found:
   p->pid = allocpid();
   p->state = USED;
-  p->tickets = DEFAULT_TICKS;
-  p->stride = STRIDE1 / p->tickets;
-  p->pass = p->stride;
-  p->ticks = 0;
 
   // Allocate a trapframe page.
   if((p->trapframe = (struct trapframe *)kalloc()) == 0){
@@ -173,10 +169,6 @@ freeproc(struct proc *p)
   p->killed = 0;
   p->xstate = 0;
   p->state = UNUSED;
-  p->tickets = 0;
-  p->stride = 0;
-  p->pass = 0;
-  p->ticks = 0;
 }
```

#### Scheduler Part

**WHAT YOU NEED TO DO** in this project is finishing the two `scheduler()` functions in this file and test them by provided user space program.

The original `void scheduler(void)` function is a Round Robin (RR) scheduling. 
```c
void
scheduler(void)
{
  struct proc *p;
  struct cpu *c = mycpu();

  c->proc = 0;
  for(;;){
    // The most recent process to run may have had interrupts
    // turned off; enable them to avoid a deadlock if all
    // processes are waiting.
    ...
    }
  }
}
```

The outer `for(;;)` loop will be launched when each cpu starts. Therefore, in the default implementation, you can find that the function keeps finding the available (i.e., `RUNNABLE`) process and run it whenever the scheduler finds one. This is known as RR scheduling. It's not hard to imagine that, the processes will be executed evenly and they will have almost the same execution time. 

```c
acquire(&p->lock);
...
release(&p->lock);
```

Acquire and release the process lock when you need to access/modify the members in structure `p` to avoid consistency issues. 

`intr_on()` is used for enabling the interrupts in OS.

`asm volatile("wfi") ` is used for inserting a assembly language `wfi`, which puts current CPU to idle and waiting till next interrput. 

```diff
 // Create a user page table for a given process, with no user memory,
@@ -449,7 +441,6 @@ wait(uint64 addr)
 //  - swtch to start running that process.
 //  - eventually that process transfers control
 //    via swtch back to the scheduler.
-#if !defined(SCHEDULER) || (SCHEDULER != LOTTERY && SCHEDULER != STRIDE)
 void
 scheduler(void)
 {
@@ -473,7 +464,6 @@ scheduler(void)
         p->state = RUNNING;
         c->proc = p;
         swtch(&c->context, &p->context);
-        ++p->ticks;  // Increment the tick count for the process.
 
         // Process is done running for now.
         // It should have changed its p->state before coming back.
@@ -490,26 +480,6 @@ scheduler(void)
   }
 }
 
-#elif SCHEDULER == LOTTERY
-/**
- * TODO: Implement the lottery scheduler.
- */
-void
-scheduler(void)
-{
-
-}
-#elif SCHEDULER == STRIDE
-/**
- * TODO: Implement the stride scheduler.
- */
-void
-scheduler(void)
-{
-
-}
-#endif
-
 // Switch to scheduler.  Must hold only p->lock
 // and have changed proc->state. Saves and restores
 // intena because intena is a property of this
@@ -723,24 +693,3 @@ procdump(void)
     printf("\n");
   }
 }
```

#### Two Kernel Functions

Two kernel functions implementation for setting tickets and getting ticks, referring [here](#kerneldefsh) for details.

```diff
-
-void proc_set_tickets(int tickets) {
-  struct proc *p = myproc();
-  acquire(&p->lock);
-  p->tickets = tickets;
-  p->stride = STRIDE1 / p->tickets;
-  release(&p->lock);
-}
-
-int getticks(int pid) {
-  struct proc *p;
-  for (p = proc; p < &proc[NPROC]; p++) {
-    acquire(&p->lock);
-    if (p->pid == pid) {
-      release(&p->lock);
-      return p->ticks;
-    }
-    release(&p->lock);
-  }
-  return -1;
-}
\ No newline at end of file
```

### /kernel/proc.h

Add necessary attributes for structure `struct proc`, refer [here](#new-member-vars) for details.

```diff
diff --git a/kernel/proc.h b/kernel/proc.h
index d5e5fc5..d021857 100644
--- a/kernel/proc.h
+++ b/kernel/proc.h
@@ -91,10 +91,6 @@ struct proc {
   int killed;                  // If non-zero, have been killed
   int xstate;                  // Exit status to be returned to parent's wait
   int pid;                     // Process ID
-  uint tickets;
-  uint stride;
-  uint pass;
-  uint ticks;
 
   // wait_lock must be held when using this:
   struct proc *parent;         // Parent process
```

### /kernel/random.c

Source file for random number generation. You would use them in lottery scheduling. Refer [here](#kerneldefsh) for details.

```diff
diff --git a/kernel/random.c b/kernel/random.c
deleted file mode 100644
index 53334b0..0000000
--- a/kernel/random.c
+++ /dev/null
@@ -1,12 +0,0 @@
-#include "types.h"
-
-static uint64 seed = 1;
-
-uint random(void) {
-    seed = seed * 6364136223846793005ULL + 1;
-    return (seed >> 32) & 0x7fffffff;
-}
-
-void srand(uint64 new_seed) {
-    seed = new_seed;
-}
\ No newline at end of file
```

### /kernel/syscall.c

Mandatory system calls definition, you have learned them in Lab 1.

```diff
diff --git a/kernel/syscall.c b/kernel/syscall.c
index 217a31b..ed65409 100644
--- a/kernel/syscall.c
+++ b/kernel/syscall.c
@@ -101,8 +101,6 @@ extern uint64 sys_unlink(void);
 extern uint64 sys_link(void);
 extern uint64 sys_mkdir(void);
 extern uint64 sys_close(void);
-extern uint64 sys_settickets(void);
-extern uint64 sys_getticks(void);
 
 // An array mapping syscall numbers from syscall.h
 // to the function that handles the system call.
@@ -128,8 +126,6 @@ static uint64 (*syscalls[])(void) = {
 [SYS_link]    sys_link,
 [SYS_mkdir]   sys_mkdir,
 [SYS_close]   sys_close,
-[SYS_settickets]  sys_settickets,
-[SYS_getticks]    sys_getticks,
 };
 
 void
```

### /kernel/syscall.h

Same to above. 

```diff
diff --git a/kernel/syscall.h b/kernel/syscall.h
index 19fc543..bc5f356 100644
--- a/kernel/syscall.h
+++ b/kernel/syscall.h
@@ -1,24 +1,22 @@
 // System call numbers
-#define SYS_fork        1
-#define SYS_exit        2
-#define SYS_wait        3
-#define SYS_pipe        4
-#define SYS_read        5
-#define SYS_kill        6
-#define SYS_exec        7
-#define SYS_fstat       8
-#define SYS_chdir       9
-#define SYS_dup         10
-#define SYS_getpid      11
-#define SYS_sbrk        12
-#define SYS_sleep       13
-#define SYS_uptime      14
-#define SYS_open        15
-#define SYS_write       16
-#define SYS_mknod       17
-#define SYS_unlink      18
-#define SYS_link        19
-#define SYS_mkdir       20
-#define SYS_close       21
-#define SYS_settickets  22
-#define SYS_getticks    23
+#define SYS_fork    1
+#define SYS_exit    2
+#define SYS_wait    3
+#define SYS_pipe    4
+#define SYS_read    5
+#define SYS_kill    6
+#define SYS_exec    7
+#define SYS_fstat   8
+#define SYS_chdir   9
+#define SYS_dup    10
+#define SYS_getpid 11
+#define SYS_sbrk   12
+#define SYS_sleep  13
+#define SYS_uptime 14
+#define SYS_open   15
+#define SYS_write  16
+#define SYS_mknod  17
+#define SYS_unlink 18
+#define SYS_link   19
+#define SYS_mkdir  20
+#define SYS_close  21
```

### /kernel/sysproc.c

System call implementations. 

```diff
diff --git a/kernel/sysproc.c b/kernel/sysproc.c
index e53385f..3b4d5bd 100644
--- a/kernel/sysproc.c
+++ b/kernel/sysproc.c
@@ -91,23 +91,3 @@ sys_uptime(void)
   release(&tickslock);
   return xticks;
 }
-
-uint64
-sys_settickets(void)
-{
-  int tickets;
-  argint(0, &tickets);
-  if (tickets < 1) {
-    return -1;
-  }
-  proc_set_tickets(tickets);
-  return 0;
-}
-
-uint64
-sys_getticks(void)
-{
-  int pid;
-  argint(0, &pid);
-  return getticks(pid);
-}
\ No newline at end of file
```

### /user/user.h

The system call interface in user space.

```diff
diff --git a/user/user.h b/user/user.h
index f09d85b..f16fe27 100644
--- a/user/user.h
+++ b/user/user.h
@@ -22,8 +22,6 @@ int getpid(void);
 char* sbrk(int);
 int sleep(int);
 int uptime(void);
-int settickets(int);
-int getticks(int);
 
 // ulib.c
 int stat(const char*, struct stat*);
diff --git a/user/usys.pl b/user/usys.pl
index 86af7cb..01e426e 100755
--- a/user/usys.pl
+++ b/user/usys.pl
@@ -36,5 +36,3 @@ entry("getpid");
 entry("sbrk");
 entry("sleep");
 entry("uptime");
-entry("settickets");
-entry("getticks");
\ No newline at end of file
```

### /user/test_scheduler.c

This is the test program in user space for you testing schedulers' behavior.

There are several arguments for this program. 
1. `SLEEP_TIME`: the time in ticks you want to make the parent process to sleep.
2. `N_PROC`: the count of processes you want to run for testing.
3. `TICKETN`: the ticket number for different process.

This parent process does three things:
1. Create `N_PROC` child processes.
2. Sleep for `SLEEP_TIME` ticks.
3. KILL all child and output their execution time (in ticks). 

All child processes do two things:
1. Set tickets for itself.
2. Do a infinite `while(1)` loop.

The expected behavior of this program is that, the parent process would output ticks for each child process and the ticks matches your scheduling strategy. Specifically, for original scheduler it should output almost same ticks for each process no matter what tickets they have and the ticks should be inversely proportinal to the number of tickets. 

```diff
diff --git a/user/test_scheduler.c b/user/test_scheduler.c
deleted file mode 100644
index 23dd138..0000000
--- a/user/test_scheduler.c
+++ /dev/null
@@ -1,49 +0,0 @@
-#include "kernel/types.h"
-#include "user/user.h"
-
-const int MAX_N_PROC = 1 << 5;
-const int MAX_TICKETS = 1 << 10;
-
-int main(int argc, char **argv) {
-    if (argc < 4) {
-        printf("Usage: %s [SLEEP_TIME in ticks] [N_PROC] [TICKET1] [TICKET2]...\n", argv[0]);
-        exit(-1);
-    }
-    int sleep_time = atoi(argv[1]);
-    int n_proc = atoi(argv[2]);
-    if (n_proc > MAX_N_PROC) {
-        printf("Error: Maximum number of processes is %d (%d received)\n", MAX_N_PROC, n_proc);
-        exit(-1);
-    }
-    int tickets[MAX_N_PROC];
-    for (int i = 0; i < n_proc; i++) {
-        tickets[i] = atoi(argv[i + 3]);
-        if (tickets[i] < 1 || tickets[i] > MAX_TICKETS) {
-            printf("Error: Ticket value must be between 1 and %d (%d received)\n", MAX_TICKETS, tickets[i]);
-            exit(-1);
-        }
-    }
-
-    int *childs = malloc(n_proc * sizeof(int));
-    for (int i = 0; i < n_proc; ++i) {
-        int pid = fork();
-        if (pid == 0) {
-            // Child process
-            settickets(tickets[i]);
-            while (1) ; // Infinite loop to keep the child process running
-        } else if (pid > 0) {
-            // Parent process
-            childs[i] = pid;
-            printf("Created child process with PID: %d and tickets: %d\n", pid, tickets[i]);
-        } else {
-            printf("Error: Fork failed\n");
-            exit(-1);
-        }
-    }
-    sleep(sleep_time);
-    for (int i = 0; i < n_proc; ++i) {
-        printf("Child PID: %d, ticks spent: %d\n", childs[i], getticks(childs[i]));
-        kill(childs[i]);
-    }
-    return 0;
-}
\ No newline at end of file
```

## Compile and Run

After you are familiar to the source code modification, you can now run the test program for default RR scheduler. 

```bash
$ make qemu
riscv64-linux-gnu-gcc    -c -o kernel/entry.o kernel/entry.S
...
qemu-system-riscv64 -machine virt -bios none -kernel kernel/kernel -m 128M -smp 1 -nographic -global virtio-mmio.force-legacy=false -drive file=fs.img,if=none,format=raw,id=x0 -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

xv6 kernel is booting

init: starting sh
$ 
```

Run our test program by:
```bash
$ ./test_scheduler 100 3 1024 512 256
```

In this test, we run 3 child processes and they have 1024, 512 and 256 tickets seperately. The expected output for this test should be closely equal ticks. The program may wait for several seconds or minutes to finish based on your CPU speed. 

If you see the output like following, you are ready to write your own scheduler!
```bash
$ ./test_scheduler 100 3 1024 512 256
Created child process with PID: 4 and tickets: 1024
Created child process with PID: 5 and tickets: 512
Created child process with PID: 6 and tickets: 256
Child PID: 4, ticks spent: 34
Child PID: 5, ticks spent: 34
Child PID: 6, ticks spent: 34
```

When you finish your lottery and stride scheduler, you can compile them by:
```bash
$ make clean
$ make SCHEDULER=LOTTERY qemu
```
and
```bash
$ make clean
$ make SCHEDULER=STRIDE qemu
```

**REMEMBER TO CLEAN** whenver you want to re-compile your code. 

The expect output for lottery should be:
```bash
$ ./test_scheduler 100 3 1024 512 256
Created child process with PID: 4 and tickets: 1024
Created child process with PID: 5 and tickets: 512
Created child process with PID: 6 and tickets: 256
Child PID: 4, ticks spent: 56
Child PID: 5, ticks spent: 32
Child PID: 6, ticks spent: 14
$ ./test_scheduler 100 3 1024 512 256
Created child process with PID: 9 and tickets: 1024
Created child process with PID: 10 and tickets: 512
Created child process with PID: 11 and tickets: 256
Child PID: 9, ticks spent: 60
Child PID: 10, ticks spent: 28
Child PID: 11, ticks spent: 15
```

The ticks for two different execution is likely to be different.

The one for stride should like:
```bash
$ ./test_scheduler 100 3 1024 512 256
Created child process with PID: 4 and tickets: 1024
Created child process with PID: 5 and tickets: 512
Created child process with PID: 6 and tickets: 256
Child PID: 4, ticks spent: 58
Child PID: 5, ticks spent: 29
Child PID: 6, ticks spent: 14
$ ./test_scheduler 100 3 1024 512 256
Created child process with PID: 8 and tickets: 1024
Created child process with PID: 9 and tickets: 512
Created child process with PID: 10 and tickets: 256
Child PID: 8, ticks spent: 58
Child PID: 9, ticks spent: 29
Child PID: 10, ticks spent: 14
$ 
```

The ticks for two different execution is likely to be same.

Try different process number, ticks and tickets and include a figure in you report like the one in stride scheduling paper. 