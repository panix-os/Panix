# make the _start function available to the linker
.global _start

# global constructor and destructor calls
.extern _init
.extern _fini

# external reference to our global constructors and kernel main functions
# which are defined in our main.cpp file. This allows assembly to call
# function in C++ by telling the compiler they exist "somewhere"
.extern px_kernel_main
# minimal panic function that works in most situations
.extern early_panic

.extern _KERNEL_START
.extern _KERNEL_END
.extern _BSS_START
.extern _BSS_SIZE

.extern _EARLY_KERNEL_START
.extern _EARLY_KERNEL_END
.extern _EARLY_BSS_START
.extern _EARLY_BSS_SIZE

.equ KERNEL_BASE, 0xC0000000
.equ LOWMEM_END, _EARLY_KERNEL_END        # lowmem ends at the 1st MB
.equ PAGE_SIZE, 4096
.equ PAGE_SHIFT, 12                 # 2^12 = 4096 = PAGE_SIZE
.equ PAGE_PERM, 3                  # default page permissions: present, read/write
.equ STACK_SIZE, 4*PAGE_SIZE        # initial kernel stack space size of 16k

.equ MULTIBOOT_MAGIC,       0x1badb002
.equ MULTIBOOT_PAGE_ALIGN,  1<<0
.equ MULTIBOOT_MEM_INFO,    1<<1
.equ MULTIBOOT_FLAGS,       (MULTIBOOT_PAGE_ALIGN | MULTIBOOT_MEM_INFO)
.equ MULTIBOOT_CHECKSUM,    -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

# Multiboot header section of our executable. See linker.ld
.section .__mbHeader, "ax", @progbits
.long MULTIBOOT_MAGIC
.long MULTIBOOT_FLAGS
.long MULTIBOOT_CHECKSUM

# Text section of our executable. See linker.ld
# This is the kernel entry point
.section .early_text, "ax", @progbits
_start:
    # save our multiboot information from grub before messing with registers
    # these can't be saved on the stack as we are about to zero it
    movl %eax, multiboot_magic
    movl %ebx, multiboot_info

    # zero the early BSS to start things off well
    movl $_EARLY_BSS_SIZE, %ecx
    xorb %al, %al
    movl $_EARLY_BSS_START, %edi
    rep
    stosb

    # identity map from 0x00000000 -> LOWMEM_END
    # WARNING: code assumes that the kernel won't be greater than 3MB
    movl $lowmem_pt, %eax
    movl %eax, page_directory
    orl $PAGE_PERM, page_directory

    xor %eax, %eax

_start.lowmem:
    movl %eax, %ecx
    shrl $PAGE_SHIFT, %ecx
    andl $0x3ff, %ecx
    movl %eax, lowmem_pt(,%ecx,4)
    orl $PAGE_PERM, lowmem_pt(,%ecx,4)

    addl $PAGE_SIZE, %eax
    cmpl $LOWMEM_END, %eax
    jl _start.lowmem

    # create virtual mappings for the kernel in the higher-half
    movl $_KERNEL_START, %edx
    shrl $22, %edx       # find which directory entry we need to use

        # the first page table
    movl $kernel_pt, %eax
    movl %eax, page_directory(,%edx,4)
    orl $PAGE_PERM, page_directory(,%edx,4)

        # the second page table
        incl %edx
        movl $pages_pt, %eax
        movl %eax, page_directory(,%edx,4)
        orl $PAGE_PERM, page_directory(,%edx,4)

    movl $_KERNEL_START, %eax # the kernel's current virtual start

_start.higher:
        # compute the page table offset
        # this only works because the two page tables are adjacent
    movl %eax, %edx
        shrl $22, %edx
        subl $0x300, %edx
        imull $PAGE_SIZE, %edx

        movl %eax, %ecx
    shrl $PAGE_SHIFT, %ecx
    andl $0x3ff, %ecx # generate kernel PTE index

    movl %eax, %ebx
    subl $KERNEL_BASE, %ebx # convert virt->physical
    movl %ebx, kernel_pt(%edx,%ecx,4)
    orl $PAGE_PERM, kernel_pt(%edx,%ecx,4)

    addl $PAGE_SIZE, %eax  # move on to the next page
    cmpl $_KERNEL_END, %eax # are we done mapping in the kernel?
    jl _start.higher

    movl $page_directory, %eax
    movl %eax, %cr3 # load CR3 with our page directory

    movl %cr0, %eax
    orl $0x80000000, %eax
    movl %eax, %cr0 # enable paging! make sure the next instruction fetch doesnt page fault

    # zero the kernel BSS
    movl $_BSS_SIZE, %ecx
    xorb %al, %al
    movl $_BSS_START, %edi
    rep
    stosb

    # adjust the stack in to the virtual area
    # setup and adjust the stack
    movl  $(stack + STACK_SIZE), %esp

/*
    # check if SSE is available
    movl $0x1, %eax
    cpuid
    test $(1<<25), %edx
    jnz _start.has_sse

    # panic because no SSE :'(
    push $no_sse_msg
    call early_panic

    # infinite loop if panic returns
    jmp _start.catchfire

_start.has_sse:
    # enable SSE
    movl %cr0, %eax
    andw $0xFFFB, %ax  # clear coprocessor emulation CR0.EM
    orw $0x2, %ax      # set coprocessor monitoring  CR0.MP
    movl %eax, %cr0
    movl %cr4, %eax
    orw $(3<<9), %ax # set CR4.OSFXSR and CR4.OSXMMEXCPT at the same time
    movl %eax, %cr4
*/
    # push kernel main parameters
    pushl multiboot_magic               # Multiboot magic number
    pushl multiboot_info                # Multiboot info structure

    # Set NULL stack frame for trace
    xor %ebp, %ebp

    # Call global constructors
    call _init
    # Enter the high-level kernel.
    call px_kernel_main
    # Call global destructors
    call _fini

    # By this point we should be into the wild world of C++
    # So, this should never be called unless the kernel returns
    _start.catchfire:
    hlt
    jmp _start.catchfire

.section .early_bss, "aw", @nobits
.align 4096
page_directory:        # should also be page aligned (hopefully)
    .space 1024*4      # reserve 1024 DWORDs for our page table pointers
lowmem_pt:
    .space 1024*4      # lowmem identity mappings
kernel_pt:
    .space 1024*4      # our kernel page table mappings
pages_pt:
    .space 1024*4      # a page table that maps pages that contain page tables

.section .early_data, "aw"
.align 4
multiboot_magic:
    .long 0
multiboot_info:
    .long 0
no_sse_msg:
    .asciz "Error: No SSE support available!"

.section .bss, "aw", @nobits
.align 4
stack:
    .space STACK_SIZE

/* vim: ft=gas :
*/
