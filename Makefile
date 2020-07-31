# Panix Kernel Makefile
# Compiles the kernel source code located in the kernel/ folder.
#
# TODO: Create seperate makefiles as needed and integrate into one makefile
#

.DEFAULT_GOAL := dist/panix32.kernel

# *****************************
# * Various Source Code Flags *
# *****************************

SYSROOT	= sysroot
INCLUDE = $(SYSROOT)/usr/include
CPP_SRC = $(shell find kernel/ -name "*.cpp")
ATT_SRC = $(shell find kernel/ -name "*.s")
HEADERS = $(shell find $(INCLUDE) -name "*.hpp" -name "*.h")
# Grub mkrescue is included here since
# I'm not sure where else it would go
MKGRUB 	= $(shell command -v grub-mkrescue)

# *********************************
# * Various Virtual Machine Flags *
# *********************************

# VM executable locations
VBOX = $(shell command -v VBoxManage)
QEMU = $(shell command -v qemu-system-$(QEMU_ARCH))
# QEMU flags
QEMU_FLAGS =		\
    -m 4G			\
    -rtc clock=host	\
    -vga std		\
    -serial stdio
QEMU_ARCH = x86_64
# Virtualbox flags
VM_NAME	= panix-box
VBOX_VM_FILE=dist/$(VM_NAME)/$(VM_NAME).vbox

# **********************************
# * 32-Bit i686 Architecture Flags *
# **********************************

# Compilers/Assemblers/Linkers
AS_32 	= $(shell command -v i686-elf-as)
GCC_32  = $(shell command -v i686-elf-gcc)
GDB_32  = $(shell command -v i686-elf-gdb)
LD_32   = $(shell command -v i686-elf-ld)
OBCP_32 = $(shell command -v i686-elf-objcopy)
# The -lgcc flag is included because it includes helpful functions used
# by GCC that would be ineffective to duplicate.
GCC_FLAGS_32 = 							\
	-m32								\
	-g									\
	-nostartfiles						\
	-nodefaultlibs						\
	-lgcc								\
	-ffreestanding						\
	-fstack-protector-all				\
	-fpermissive						\
	-fno-use-cxa-atexit					\
	-fno-builtin						\
	-fno-rtti							\
	-fno-exceptions						\
	-fno-leading-underscore	        	\
	-Wno-write-strings					\
	-std=c++2a
# i686 Assembler flags
AS_FLAGS_32 = --32
# i686 Linker flags
LD_FLAGS_32 = -melf_i386
LD_SCRIPT_32 = kernel/arch/x86/linker.ld
# Kernel define flags
KRNL_FLAGS_32 = 						\
	-I ${SYSROOT}/usr/include/kernel/

# ************************************
# * 64-Bit x86_64 Architecture Flags *
# ************************************



# ***********************************
# * Source Code Compilation Targets *
# ***********************************

# All objects
OBJ = $(patsubst kernel/%.cpp, obj/%.o, $(CPP_SRC))	\
	  $(patsubst kernel/%.s, obj/%.o, $(ATT_SRC))
# Object directories, mirroring source
OBJ_DIRS = $(subst kernel, obj, $(shell find kernel -type d))

# Create object file directories
.PHONY: mkdir_obj_dirs
mkdir_obj_dirs:
	mkdir -p $(OBJ_DIRS)

# Compile sources to objects
obj/%.o: kernel/%.cpp $(HEADERS)
	$(MAKE) mkdir_obj_dirs
	$(GCC_32) $(GCC_FLAGS_32) $(KRNL_FLAGS_32) -c -o $@ $<

obj/%.o: kernel/%.s
	$(MAKE) mkdir_obj_dirs
	$(AS_32) $(AS_FLAGS_32) -o $@ $<

# Link objects into BIN
dist/panix32.kernel: $(LD_SCRIPT_32) $(OBJ)
	@ mkdir -p dist
	$(LD_32) $(LD_FLAGS_32) -T $< -o $@ $(OBJ)
	$(OBCP_32) --only-keep-debug dist/panix32.kernel dist/panix.sym

# ********************************
# * Kernel Distribution Creation *
# ********************************

# Create bootable ISO
iso32: dist/panix32.kernel
	@ mkdir -p iso/boot/grub
	@ cp $< iso/boot/
	@ cp boot/grub32.cfg iso/boot/grub/grub.cfg
	@ $(MKGRUB) -o dist/panix32.iso iso
	@ rm -rf iso

vdi32: dist/panix32.kernel
	@ echo Building VDI image of Panix...
	@ qemu-img convert -f raw -O vdi dist/panix32.kernel dist/panix.vdi
	@ echo Done building VDI image of Panix!

vmdk32: dist/panix32.kernel
	@ echo "\nBuilding VMDK image of Panix..."
	@ qemu-img convert -f raw -O vmdk dist/panix32.kernel dist/panix.vmdk
	@ echo Done building VMDK image of Panix!

# ***************************
# * Virtual Machine Testing *
# ***************************

# Run Panix in QEMU
.PHONY: run
run: dist/panix32.kernel
	$(QEMU)						\
	-kernel dist/panix32.kernel \
	$(QEMU_FLAGS)

# Create Virtualbox VM
.PHONY: $(VBOX_VM_FILE)
vbox-create: dist/panix32.iso
	$(VBOX) createvm --register --name $(VM_NAME) --basefolder $(shell pwd)/dist
	$(VBOX) modifyvm $(VM_NAME)					\
	--memory 256 --ioapic on --cpus 2 --vram 16	\
	--graphicscontroller vboxvga --boot1 disk	\
	--audiocontroller sb16 --uart1 0x3f8 4		\
	--uartmode1 file $(shell pwd)/com1.txt 
	$(VBOX) storagectl $(VM_NAME) --name "DiskDrive" --add ide --bootable on
	$(VBOX) storageattach $(VM_NAME) --storagectl "DiskDrive" --port 1 --device 1 --type dvddrive --medium dist/panix32.iso 

.PHONY: virtualbox
vbox: vbox-create
	$(VBOX) startvm --putenv --debug $(VM_NAME)

# Open the connection to qemu and load our kernel-object file with symbols
.PHONY: debug
debug: dist/panix32.iso
	# Start QEMU with debugger
	($(QEMU) 			\
	-S -s 				\
	-drive format=raw,file=$< 	\
	$(QEMU_FLAGS) &)
	sleep 1
	wmctrl -xr qemu.Qemu-system-$(QEMU_ARCH) -b add,above
	# After this start the visual studio debugger
	# gdb dist/panix32.kernel

# ************************************
# * Doxygen Documentation Generation *
# ************************************

.PHONY: docs
docs:
	@ echo Generating docs according to the Doxyfile...
	@ doxygen ./Doxyfile

# ********************
# * Cleaning Targets *
# ********************

# Clear out objects and BIN
.PHONY: clean
clean:
	@ echo Cleaning obj directory...
	@ rm -rf obj
	@ echo Cleaning bin files...
	@ rm -rf dist/*.kernel
	@ rm -rf dist/*.sym
	@ rm -rf dist/*.vdi
	@ rm -rf dist/*.vmdk
	@ rm -rf dist/*.iso
	@ echo "Done cleaning!"

.PHONY: clean-vm
clean-vm:
	@ echo Removing VM
	@ $(VBOX) unregistervm $(VM_NAME) --delete
