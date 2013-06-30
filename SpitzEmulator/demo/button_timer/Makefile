#*******************************************************************************
# Makefile for Cross-Compile to ARM target. 
#
# Usage:
# - change "NAME" below with your assembly program
# - build (assembling and linking):
#   > make
# - debug:
#   > make db
# 	or if you have arm-elf-insight:
#	> make insight
# note: kernel.img can be preloaded to SDcard
#
#*******************************************************************************

NAME = button_timer_new

CROSS_COMPILE ?= arm-elf
CC := $(CROSS_COMPILE)-gcc
LD := $(CROSS_COMPILE)-ld
AS := $(CROSS_COMPILE)-as
OBJCOPY := $(CROSS_COMPILE)-objcopy
OBJDUMP := $(CROSS_COMPILE)-objdump

DB   = $(CROSS_COMPILE)-gdb
INSIGHT   = $(CROSS_COMPILE)-insight

AFLAGS  = -gstabs+ -warn -fatal-warnings
LFLAGS  = -T ldscript

OBJS = $(NAME).o

all: $(NAME).elf kernel.img

db: $(NAME).elf
	$(DB) $(NAME).elf

insight: $(NAME).elf
	$(INSIGHT) $(NAME).elf

kernel.img:	$(NAME)
	$(OBJCOPY) -O binary $< $@

$(NAME).elf: $(NAME)
	$(OBJCOPY) $< $@
	$(OBJDUMP) -D $@ > $(NAME).lst

$(NAME): $(OBJS)	
	$(LD) $^ -o $@ $(LFLAGS) --M $@.mp

%.o: %.s
	$(AS) $< -o $@ $(AFLAGS)

clean:
	rm -f *.lst *.elf *.mp *.o $(NAME) kernel.img
