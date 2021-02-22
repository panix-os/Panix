/**
 * @file GlobalDescriptorTable.hpp
 * @author Keeton Feavel (keetonfeavel@cedarville.edu)
 * @brief The Global Descriptor Table (GDT) is specific to the IA32 architecture.
 * It contains entries telling the CPU about memory segments.
 * @version 0.3
 * @date 2019-09-26
 *
 * @copyright Copyright Keeton Feavel (c) 2019
 *
 */
#pragma once

#include <stdint.h>

/**
 * @brief Thanks to the OSDev Wiki for this solution. We had previously
 * used the James Molloy / os-tutorial repo version but it was a lot more
 * code and a lot less elegant.
 *
 */
#define SEG_TYPE(x)  ((x) << 0x04)  // Descriptor type (0 for system, 1 for code/data)
#define SEG_PRES(x)  ((x) << 0x07)  // Present
#define SEG_SAVL(x)  ((x) << 0x0C)  // Available for system use
#define SEG_LONG(x)  ((x) << 0x0D)  // Long mode
#define SEG_SIZE(x)  ((x) << 0x0E)  // Size (0 for 16-bit, 1 for 32)
#define SEG_GRAN(x)  ((x) << 0x0F)  // Granularity (0 for 1B - 1MB, 1 for 4KB - 4GB)
#define SEG_PRIV(x) (((x) &  0x03) << 0x05)   // Set privilege level (0 - 3)

#define SEG_DATA_RD          0x00   // Read-Only
#define SEG_DATA_RDA         0x01   // Read-Only, accessed
#define SEG_DATA_RDWR        0x02   // Read/Write
#define SEG_DATA_RDWRA       0x03   // Read/Write, accessed
#define SEG_DATA_RDEXPD      0x04   // Read-Only, expand-down
#define SEG_DATA_RDEXPDA     0x05   // Read-Only, expand-down, accessed
#define SEG_DATA_RDWREXPD    0x06   // Read/Write, expand-down
#define SEG_DATA_RDWREXPDA   0x07   // Read/Write, expand-down, accessed
#define SEG_CODE_EX          0x08   // Execute-Only
#define SEG_CODE_EXA         0x09   // Execute-Only, accessed
#define SEG_CODE_EXRD        0x0A   // Execute/Read
#define SEG_CODE_EXRDA       0x0B   // Execute/Read, accessed
#define SEG_CODE_EXC         0x0C   // Execute-Only, conforming
#define SEG_CODE_EXCA        0x0D   // Execute-Only, conforming, accessed
#define SEG_CODE_EXRDC       0x0E   // Execute/Read, conforming
#define SEG_CODE_EXRDCA      0x0F   // Execute/Read, conforming, accessed

// Ring 0 Privilege Levels (Kernel)
#define GDT_CODE_PL0 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(0) | SEG_CODE_EXRD

#define GDT_DATA_PL0 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(0) | SEG_DATA_RDWR

// Ring 1 Privilege Levels (Reserved)
#define GDT_CODE_PL1 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(1) | SEG_CODE_EXRD

#define GDT_DATA_PL1 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(1) | SEG_DATA_RDWR

// Ring 2 Privilege Levels (Reserved for drivers)
#define GDT_CODE_PL2 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(2) | SEG_CODE_EXRD

#define GDT_DATA_PL2 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(2) | SEG_DATA_RDWR

// Ring 3 Privilege Levels (Userspace)
#define GDT_CODE_PL3 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(3) | SEG_CODE_EXRD

#define GDT_DATA_PL3 SEG_TYPE(1) | SEG_PRES(1) | SEG_SAVL(0) | \
                     SEG_LONG(0) | SEG_SIZE(1) | SEG_GRAN(1) | \
                     SEG_PRIV(3) | SEG_DATA_RDWR

/**
 * @brief GDT Code & Data Segment Selector Struct
 *
 */
struct gdt_entry {
    // These are descriptors in the GDT that have S=1. Bit 3 of "type" indicates whether it's (0) Data or (1) Code.
    // See https://wiki.osdev.org/Descriptors#Code.2FData_Segment_Descriptors for details on code & data segments.
    uint16_t limit_low;     // Limit
    uint16_t base_low;      // Base
    uint8_t  base_middle;   // Base
    uint8_t  access;        // Type
    uint8_t  granularity;   // Bits 0..3: limit, Bits 4..7: additional data/code attributes
    uint8_t  base_high;     // Base
} __attribute__((packed));
typedef struct gdt_entry gdt_entry_t;

/**
 * @brief GDT Pointer Struct
 *
 */
struct gdt_ptr {
    unsigned short limit;   // The upper 16 bits of all selector limits
    unsigned int base;      // The address of the first gdt_segment
} __attribute__((packed));
typedef struct gdt_ptr gdt_ptr_t;

/**
 * @brief Setup and install the GDT onto the system.
 *
 */
extern void px_gdt_install();
