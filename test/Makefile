EEPROM_PART=SST39SF040

.PHONY: all clean eeprom
.SUFFIXES: .lst .bin .hex .map .lbl

AS=vasm6502
ASFLAGS=-dotdir -c02 -Fihex
HU=srec_cat
PU=minipro
PUFLAGS=-p $(EEPROM_PART)

all: $(IMAGE)

clean:
	-rm -f *.hex *.lst *.bin


$(IMAGE): romtest.hex romfill_9.hex romfill_A.hex romfill_B.hex romfill_C.hex romfill_D.hex romfill_E.hex romfill_F.hex
	$(HU) romtest.hex -Intel \
	      romfill_9.hex -Intel -Offset 0x10000 \
	      romfill_A.hex -Intel -Offset 0x20000 \
	      romfill_B.hex -Intel -Offset 0x30000 \
	      romfill_C.hex -Intel -Offset 0x40000 \
	      romfill_D.hex -Intel -Offset 0x50000 \
	      romfill_E.hex -Intel -Offset 0x60000 \
	      romfill_F.hex -Intel -Offset 0x70000 \
	      -Output -Intel > $@

eeprom: $(IMAGE)
	$(PU) $(PUFLAGS) -uP -w $<

romtest.hex: vectors.h.s ports.h.s romtest.h.s romtest.s

ramtest.hex: vectors.h.s ports.h.s ramtest.s

aciatest.hex: vectors.h.s ports.h.s aciatest.s

irqtest.hex: vectors.h.s ports.h.s irqtest.s

romfill_9.hex: romfill_9.s romtest.h.s
romfill_A.hex: romfill_A.s romtest.h.s
romfill_B.hex: romfill_B.s romtest.h.s
romfill_C.hex: romfill_C.s romtest.h.s
romfill_D.hex: romfill_D.s romtest.h.s
romfill_E.hex: romfill_E.s romtest.h.s
romfill_F.hex: romfill_F.s romtest.h.s

%.hex: %.s
	$(AS) $(ASFLAGS) $< -o $@ -L $*.lst

