FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu

WORKDIR /
RUN git clone https://github.com/gdjs2/xv6-riscv-UCR-CS202-Fall24.git
WORKDIR /xv6-riscv-UCR-CS202-Fall24