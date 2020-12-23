/**
 * TODO: Refactor this file a ton or completely rewrite because it was basically taken from toaruOS.
 * @file gdt.cpp
 * @author Keeton Feavel (keetonfeavel@cedarville.edu)
 * @brief The Global Descriptor Table (GDT) is specific to the IA32 architecture.
 * It contains entries telling the CPU about memory segments.
 * @version 0.3
 * @date 2019-11-14
 *
 * @copyright Copyright the Panix Contributors (c) 2019
 *
 */
#include <arch/arch.hpp>
#include <lib/string.hpp>
#include <lib/stdio.hpp>
#include <dev/tty/tty.hpp>

#define GDT_NUM_ENTRIES 6

// Defined in the gdt_flush.s file.
extern "C" void gdt_flush(uintptr_t);
// Function declarations
void px_kernel_stack(uintptr_t stack);
void px_tss_set_gate(int32_t num, uint16_t ss0, uint32_t esp0);
void px_gdt_set_gate(uint8_t num, uint64_t base, uint64_t limit, uint16_t flags);
// Define our local variables
gdt_entry_t gdt_entries[GDT_NUM_ENTRIES];
gdt_ptr_t   gdt_ptr;
tss_entry_t tss_entry;

void px_kernel_stack(uint32_t stack) {
    // Update TSS kernel stack location
	tss_entry.esp0 = stack;
}

void px_tss_set_gate(int32_t num, uint16_t ss0, uint32_t esp0) {
    // Convert the TSS locations to GDT data
	uintptr_t base  = (uintptr_t)&tss_entry;
	uintptr_t limit = base + sizeof(tss_entry);

    // Ensure all values are zero
	memset(&tss_entry, 0x0, sizeof(tss_entry));
    // Update specific TSS register values
	tss_entry.ss0 = ss0;
	tss_entry.esp0 = esp0;
	tss_entry.iomap_base = sizeof(tss_entry);

    // Install the TSS in the last GDT location
    px_gdt_set_gate(num, base, limit, SEG_PRES(1) | SEG_CODE_EXA | SEG_SIZE(1));
}

void px_gdt_set_gate(uint8_t num, uint64_t base, uint64_t limit, uint16_t flags) {
    // 32-bit address space
    // Now we have to squeeze the (32-bit) limit into 2.5 regiters (20-bit).
    // This is done by discarding the 12 least significant bits, but this
    // is only legal, if they are all == 1, so they are implicitly still there

    // so if the last bits aren't all 1, we have to set them to 1, but this
    // would increase the limit (cannot do that, because we might go beyond
    // the physical limit or get overlap with other segments) so we have to
    // compensate this by decreasing a higher bit (and might have up to
    // 4095 wasted bytes behind the used memory)
    uint64_t descriptor = 0;

    // Create the high 32 bit segment
    descriptor =  base         & 0xFF000000;    // base direct map
    descriptor |= (base >> 16) & 0x000000FF;    // base 23-16 : 7-0
    descriptor |= (flags << 8) & 0x00F0FF00;    // flags 16-11 : 24-19 7-0 : 15-8
    descriptor |= limit        & 0x000F0000;    // limit direct map
    // Shift by 32 to move to the lower half of the section
    descriptor <<= 32;
    // Create the low 32 bit segment
    descriptor |= (base << 16) & 0xFFFF0000;    // base 15-0 : 31-16
    descriptor |= limit        & 0x0000FFFF;    // limit direct map
    // Copy the descriptor value into our GDT entries array
    memcpy(&gdt_entries[num], &descriptor, sizeof(uint64_t));
}

void px_gdt_install() {
    px_kprintf(DBG_INFO "Installing the GDT...\n");
    gdt_ptr.limit = sizeof(gdt_entries) - 1;
    gdt_ptr.base  = (uint32_t)&gdt_entries;

    px_gdt_set_gate(0, 0, 0, 0);                     // Null segment
    px_gdt_set_gate(1, 0, 0x000FFFFF, GDT_CODE_PL0); // Kernel code segment
    px_gdt_set_gate(2, 0, 0x000FFFFF, GDT_DATA_PL0); // Kernel data segment
    px_gdt_set_gate(3, 0, 0x000FFFFF, GDT_CODE_PL3); // User mode code segment
    px_gdt_set_gate(4, 0, 0x000FFFFF, GDT_DATA_PL3); // User mode data segment
    px_tss_set_gate(5, 0x10, 0x0);                   // TSS entry

    gdt_flush((uint32_t)&gdt_ptr);
    tss_flush();
    px_kprintf(DBG_OKAY "Installed the GDT.\n");
}