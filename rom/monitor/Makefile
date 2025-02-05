.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

EXECUTABLE=monitor
LOAD_OFFSET=0xF000
EXECUTION_START=0xF014
LD_CONFIG=$(EXECUTABLE).cfg
BIN_IMAGE=$(EXECUTABLE).bin
S19_IMAGE=$(EXECUTABLE).s19
HEX_IMAGE=$(EXECUTABLE).hex

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
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

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

$(S19_IMAGE): $(BIN_IMAGE)
	srec_cat $< -Binary -Offset $(LOAD_OFFSET) -Output -Motorola \
	    -execution-start-address=$(EXECUTION_START) >$@

$(HEX_IMAGE): $(BIN_IMAGE)
	srec_cat $< -Binary -Offset $(LOAD_OFFSET) -Output -Intel \
	    -execution-start-address=$(EXECUTION_START) >$@

$(BIN_IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

%.o: */%.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
