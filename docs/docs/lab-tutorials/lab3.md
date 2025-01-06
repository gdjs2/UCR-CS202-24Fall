# Lab 3 - Kernel Thread

## Before Start:

Take a look at [our project repo](https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24). We have a new [kernel-thread-lab branch](https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24/tree/kernel-thread-lab) published. In this lab, you need implement your work based on this branch. 

Another very important thing is reading section 2.4 in [xv6 book](https://pdos.csail.mit.edu/6.828/2023/xv6/book-riscv-rev3.pdf), especially figure 2.3. And also, read necessary part, make sure you understand what Trapframe and Trapoline are. 

## Pull the Repo

Clone the repo to your local machine. 
```bash
$ git clone https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24.git
```

Change directory and checkout to scheduler-lab branch. 
```bash
$ git checkout kernel-thread-lab
```

## What to do?

I believe you have had a relatively good understanding to xv6. Therefore, I wouldn't provide a step-by-step instructions for this lab. However, you can check `TODO:` symbols in the code to find what you are expected to finish first. 

The brief idea for this lab is implementing kernel thread support for xv6. You are not expected to write a new thread control block on your own, instead you can reuse `struct proc`. We have added two instance variables `thread_count` and `thread_id` in `struct proc`. They are enough for you to achieve thread allocation and memory management. However, you can/may need add more instance here to support complex management. 

There are 4 `TODO:` symbols in `proc.c`.

1. `allocthread()`, which is similar to `allocproc()`.
2. `freeproc()`, because we reuse `struct proc`, some modification should be added here to support thread. 
3. `proc_pagetable()`, you can reuse this function for allocate a pagetable for thread. You can also implement a seperate function. Both methods are accepted. 
4. `thread_freepagetable()`, the things should be freed for thread and process are different. Two major things are kernel stack and trapframe.

In `trap.c`, you need to change `userret()` call. **THIS PART IS DIFFICULT**. You need to read some assembly code in `kernel/trampoline.S`. There are two functions in `trampoline.S`, one is for user space -> kernel space, another is for kernel space -> user space. Make sure you understand the modification in these two functions. 

The last thing you need to do is implementing `thread.c`-the thread library in user space. You are required to implement another lock here, which is usable in memory access for threads. You are not required to implement a `join()` function, but you can if you want. 

## Test

After you finish your kernel thread implementation, there is one user space program `kt_test` provided to test your implementaion. This user space program only tests whether the threads share the same memory space and its functionality. We would grade your work mainly based on this program. 

## Requirments:

The kernel thread you implement is expected supporting:

1. Share memory space
2. Memory safe

The kernel thread you implement do **NOT** need:

1. Share file descriptors.
2. `exit()` function like traditional Linux. Traditionally, any thread calls `exit()` would terminate the **PROCESS**. However, in this lab, a thread calls `exit()` will only terminate itself and don't affect other processes/threads. 

Besides the modification indicated in the source file, you will still need add/modify some code to make your code **MEMORY SAFE** and **EXIT CORRECTLY**. Make sure you free all memory allocated by `*alloc()` and also, all **MEMORY SIZE VARs** are correct. 

## Grade

Some critical grading points:

1. We won't directly test `exit()` function, however you still need to clarify how you change your code to achieve the resource maintainance for threads. 
2. Correct memory space shared among threads. 
3. Correct lock implementation.
4. Memory safe
5. Explanation about trampoline and trapframe in detail.