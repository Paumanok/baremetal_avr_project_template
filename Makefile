CC = avr-gcc
CXX = avr-g++
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
FORMAT = ihex
SIZE = avr-size
NM = avr-nm
AVRDUDE = avrdude
REMOVE = rm -f

MCU = atmega32u4
ARCH = AVR8
F_CPU = 16000000UL
F_USB = $(F_CPU)

AVRDUDE_MCU = m32u4
AVRDUDE_PORT = /dev/ttyACM0
AVRDUDE_PROGRAMMER = avr109
AVRDUDE_SPEED = -B 1MHz

AVRDUDE_FLAGS = -p $(AVRDUDE_MCU)
AVRDUDE_FLAGS += -P $(AVRDUDE_PORT)
AVRDUDE_FLAGS += -c $(AVRDUDE_PROGRAMMER)



LFUSE = 0x9f
HFUSE = 0xd1

TARGET = main

# Optional assembler flags.
#  -Wa,...:   tell GCC to pass this to the assembler.
#  -ahlms:    create listing
#  -gstabs:   have the assembler create line number information; note that
#             for use in COFF files, additional information about filenames
#             and function names needs to be present in the assembler source
#             files -- see avr-libc docs [FIXME: not yet described there]
ASFLAGS = -Wa,-adhlns=$(<:.S=.lst),-gstabs 


# Optional linker flags.
#  -Wl,...:   tell GCC to pass this to linker.
#  -Map:      create map file
#  --cref:    add cross reference to  map file
LDFLAGS += -Wl,-Map=$(TARGET).map,--cref

ARDDIR = /home/matt/.arduino15/packages/arduino/hardware/avr/1.8.6/

### These macros pertain to supporting Arduino libs
ifndef NO_ARDUINO
	LDFLAGS += -lm # -lm = math library
	ARDLIBDIR 		= $(ARDDIR)libraries
	ARDCOREDIR 		= $(ARDDIR)cores/arduino

	# add Arduino sources and include directories to PSRC and EXTRAINCDIRS
	PSRC += $(filter-out $(ARDCOREDIR)/main.cpp,  $(wildcard $(ARDCOREDIR)/*.cpp))
	SRC += $(wildcard $(ARDCOREDIR)/*.c)
	ASRC += $(wildcard $(ARDCOREDIR)/*.S)
	EXTRAINCDIRS += $(ARDCOREDIR)
	PSRC += $(foreach lib,$(ARDLIBS),$(ARDLIBDIR)/$(lib)/$(lib).cpp)
	EXTRAINCDIRS += $(foreach lib,$(ARDLIBS),$(ARDLIBDIR)/$(lib))
endif

PSRC += main.cpp 
# Define all object files.
OBJ =  $(ASRC:.S=.S.o) $(SRC:.c=.o) $(PSRC:.cpp=.o)
# Define all listing files.
LST = $(ASRC:.S=.lst) $(SRC:.c=.lst) $(PSRC:.cpp=.lst) 

CDEFS =  -DUSB_PID=8036 -DUSB_VID=2341 -DF_CPU=$(F_CPU)
OPTLEVEL = s
CFLAGS = -DF_CPU=$(F_CPU)UL
CFLAGS = -DF_USB=$(F_CPU)
CFLAGS += $(CDEFS)
CFLAGS += -O$(OPTLEVEL)
CFLAGS += -mmcu=$(MCU)
CFLAGS += -I$(ARDDIR)variants/leonardo
CFLAGS += -I$(ARDCOREDIR)
CFLAGS += -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums
CFLAGS += -ffunction-sections -fdata-sections -fcommon -flto
#CFLAGS += -v
CFLAGS += -Wall 

#CXXFLAGS = $(CFLAGS)



# Combine all necessary flags and optional flags.
# Add target processor to flags.
#ALL_CFLAGS 		= -mmcu=$(MCU) -I. $(CFLAGS) -Wa,-adhlns=$(<:.c=.lst)
ALL_CFLAGS 		= -I. $(CFLAGS) -Wa,-adhlns=$(<:.c=.lst)
ALL_CXXFLAGS 	=  -I. $(CFLAGS) -fno-threadsafe-statics -Wa,-adhlns=$(<:.cpp=.lst)
ALL_ASFLAGS 	= -mmcu=$(MCU) -I. -x assembler-with-cpp $(ASFLAGS) 

MSG_LINKING = "ah shit linking"

# Default target: make program!
all: gccversion sizebefore\
	$(TARGET).elf $(TARGET).hex $(TARGET).eep $(TARGET).lss $(TARGET).sym sizeafter



gccversion:
	@$(CC) --version

HEXSIZE = $(SIZE) --target=$(FORMAT) $(TARGET).hex
ELFSIZE = $(SIZE) -A $(TARGET).elf
# Display size of file.
sizebefore:
	@if [ -f $(TARGET).elf ]; then echo;  $(ELFSIZE); echo; fi

sizeafter:
	@if [ -f $(TARGET).elf ]; then echo;  $(ELFSIZE); echo; fi




# Create final output files (.hex, .eep) from ELF output file.
%.hex: %.elf
	@echo
	@echo $(MSG_FLASH) $@
	$(OBJCOPY) -O $(FORMAT) -R .eeprom $< $@

%.eep: %.elf
	@echo
	@echo $(MSG_EEPROM) $@
	-$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom="alloc,load" \
	--change-section-lma .eeprom=0 -O $(FORMAT) $< $@

# Create extended listing file from ELF output file.
%.lss: %.elf
	@echo
	@echo $(MSG_EXTENDED_LISTING) $@
	$(OBJDUMP) -h -S $< > $@

# Create a symbol table from ELF output file.
%.sym: %.elf
	@echo
	@echo $(MSG_SYMBOL_TABLE) $@
	avr-nm -n $< > $@



# Link: create ELF output file from object files.
.SECONDARY: $(TARGET).elf
.PRECIOUS: $(OBJ)
%.elf: $(OBJ)
	@echo
	@echo $(MSG_LINKING) $@
	$(CC) $(ALL_CFLAGS) $(OBJ) --output $@ $(LDFLAGS)


# Compile: create object files from C source files.
%.o: %.c
	@echo
	@echo $(MSG_COMPILING) $<
	$(CC) -c $(ALL_CFLAGS) $< -o $@


# Compile: create assembler files from C source files.
%.s: %.c
	$(CC) -S $(ALL_CFLAGS) $< -o $@


# Compile: create object files from C++ source files
%.o: %.cpp
	@echo
	@echo $(MSG_COMPILING) $<
	$(CXX) -c $(ALL_CXXFLAGS) $< -o $@

# Compile: create assembler files from C source files.
%.s: %.cpp
	$(CC) -S $(ALL_CXXFLAGS) $< -o $@


# Assemble: create object files from assembler source files.
%.S.o: %.S
	@echo
	@echo $(MSG_ASSEMBLING) $<
	$(CC) -c $(ALL_ASFLAGS) $< -o $@


isp: $(TARGET).hex
	$(AVRDUDE) $(AVRDUDE_FLAGS) -U flash:w:$(TARGET).hex


clean :
	@echo
	@echo $(MSG_CLEANING)
	$(REMOVE) $(TARGET).hex
	$(REMOVE) $(TARGET).eep
	$(REMOVE) $(TARGET).obj
	$(REMOVE) $(TARGET).cof
	$(REMOVE) $(TARGET).elf
	$(REMOVE) $(TARGET).map
	$(REMOVE) $(TARGET).obj
	$(REMOVE) $(TARGET).a90
	$(REMOVE) $(TARGET).sym
	$(REMOVE) $(TARGET).lnk
	$(REMOVE) $(TARGET).lss
	$(REMOVE) $(TARGET).lst
	$(REMOVE) $(OBJ)
	$(REMOVE) $(LST)
	$(REMOVE) $(SRC:.c=.s)
	$(REMOVE) $(SRC:.c=.d)
	$(REMOVE) $(PSRC:.cpp=.s)
	$(REMOVE) $(PSRC:.cpp=.d)
	$(REMOVE) *~
