# ***************************************************************
# *     Makefile                                                *
# *                                                             *
# ***************************************************************

LD = arm-elf-ld
AS = arm-elf-as
EX = arm-elf-insight

AFLAGS  =  -gstabs
LFLAGS  =  -Map memory.map -T ldscript

talker: talker.elf
	$(EX) talker.elf
	
i2c: i2c.elf
	$(EX) i2c.elf
	
talker.elf: talker.o
	$(LD) $(LFLAGS) -o talker.elf talker.o	

i2c.elf: i2c.o
	$(LD) $(LFLAGS) -o i2c.elf i2c.o	
	
%.o: %.s
	$(AS) $< -o $@ $(AFLAGS)
	
clean:
	rm -f *.o *.lst *.elf *.map