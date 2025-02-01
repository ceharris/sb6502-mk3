.PHONY: all clean eeprom rom.bin
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

INCLUDES=rom.cfg
EEPROM_PART=SST39SF040

AS=ca65
LD=ld65
PU=minipro
PUFLAGS=-p $(EEPROM_PART)

ASFLAGS=--cpu 65c02
LDFLAGS=--config rom.cfg

all: rom.bin

eeprom:	rom.bin
	$(PU) $(PUFLAGS) -uP -w $<
clean:
	make -C ipl clean
	make -C loader clean
	make -C monitor clean
	make -C msbasic clean
	make -C snake clean
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

rom.bin:
	make -C ipl all
	make -C loader all
	make -C monitor all
	make -C msbasic all
	make -C snake all
	$(AS) $(ASFLAGS) rom.s -o rom.o -l $*.lst
	$(LD) $(LDFLAGS) rom.o -o $@ -m $*.map -Ln $*.lbl
