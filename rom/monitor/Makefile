.PHONY: all clean
.SUFFIXES: .bin .hex .lbl .lst .map .o .s .s19 .sym .tmp

EXECUTABLE=monitor
LOAD_OFFSET=0xF000
EXECUTION_START_LABEL=monitor
LD_CONFIG=$(EXECUTABLE).cfg
BIN_IMAGE=$(EXECUTABLE).bin
S19_IMAGE=$(EXECUTABLE).s19
HEX_IMAGE=$(EXECUTABLE).hex
ENTRY_TMP=entry.tmp

INCLUDES=$(LD_CONFIG) \
        ../include/ascii.h.s  \
	../include/ansi.h.s \
	../include/acia.h.s \
	../include/hex.h.s \
	../include/ports.h.s \
	../include/prog.h.s \
	../include/stdio.h.s \
	registers.h.s

MODULES=monitor.o fill.o peek.o poke.o quit.o hex.o stdio.o acia.o registers.o vectors.o

AS=ca65
LD=ld65

ASFLAGS=--cpu 65c02 -I ../include -DACIA_ISR_INCLUDED=1
LDFLAGS=--config $(LD_CONFIG)

all: $(S19_IMAGE) $(HEX_IMAGE)

clean:
	-rm -f *.bin *.hex *.lbl *.lst *.map *.o *.s19 *.sym *.tmp

acia.o: ../lib/acia.s $(INCLUDES)
fill.o: fill.s $(INCLUDES)
hex.o: ../lib/hex.s $(INCLUDES)
monitor.o: monitor.s $(INCLUDES)
peek.o: peek.s $(INCLUDES)
poke.o: poke.s $(INCLUDES)
quit.o: quit.s $(INCLUDES)
registers.o: registers.s $(INCLUDES)
stdio.o: ../lib/stdio.s $(INCLUDES)
vectors.o: vectors.s $(INCLUDES)

$(S19_IMAGE): $(BIN_IMAGE) $(ENTRY_TMP)
	EXECUTION_START=$$(cat $(ENTRY_TMP)); \
	srec_cat $< -Binary -Offset $(LOAD_OFFSET) -Output -Motorola \
	    -execution-start-address=$$EXECUTION_START >$@

$(HEX_IMAGE): $(BIN_IMAGE) $(ENTRY_TMP)
	EXECUTION_START=$$(cat $(ENTRY_TMP)); \
	srec_cat $< -Binary -Offset $(LOAD_OFFSET) -Output -Intel \
	    -execution-start-address=$$EXECUTION_START >$@

$(BIN_IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

$(ENTRY_TMP): $(BIN_IMAGE)
	grep "$(EXECUTION_START_LABEL)" $(EXECUTABLE).lbl | head -1 | cut -f2 -d' ' > $(ENTRY_TMP); \
	EXECUTION_START=$$(cat $(ENTRY_TMP)); \
	echo "0x$${EXECUTION_START}" > $(ENTRY_TMP)

%.o: */%.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
