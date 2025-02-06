.PHONY: all clean

.SUFFIXES: .bin .hex .lbl .lst .map .o .s .s19 .sym .tmp

EXECUTABLE=msbasic
LOAD_OFFSET=0xD000
EXECUTION_START_LABEL=COLD_START
LD_CONFIG=$(EXECUTABLE).cfg
BIN_IMAGE=$(EXECUTABLE).bin
S19_IMAGE=$(EXECUTABLE).s19
HEX_IMAGE=$(EXECUTABLE).hex
ENTRY_TMP=entry.tmp

INCLUDES=$(LD_CONFIG) ../include/acia.h.s ../include/stdio.h.s

SOURCES=array.s chrget.s defines.s error.s eval.s extra.s float.s flow1.s flow2.s \
	init.s inline.s input.s iscntc.s loadsave.s macros.s memory.s message.s misc1.s \
        misc2.s msbasic.s poke.s print.s program.s rnd.s string.s token.s trig.s \
        var.s zeropage.s defines_sbmk3.s sbmk3_extra.s sbmk3_iscntc.s

MODULES=msbasic.o acia.o stdio.o

AS=ca65
LD=ld65

ASFLAGS=--cpu 65c02 -Dsbmk3 -I ../include -DACIA_ISR_INCLUDED=1
LDFLAGS=--config $(LD_CONFIG)

all: $(S19_IMAGE) $(HEX_IMAGE)

clean:
	-rm -f *.bin *.hex *.lbl *.lst *.map *.o *.s19 *.sym *.tmp

msbasic.o: $(SOURCES) $(INCLUDES)

acia.o: ../lib/acia.s $(INCLUDES)
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

stdio.o: ../lib/stdio.s $(INCLUDES)
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

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

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
