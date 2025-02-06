.PHONY: all clean
.SUFFIXES: .bin .o .lst .map .s .sym .lbl

EXECUTABLE=ehbasic
LOAD_OFFSET=0xD000
EXECUTION_START_LABEL=RES_vec
LD_CONFIG=$(EXECUTABLE).cfg
BIN_IMAGE=$(EXECUTABLE).bin
S19_IMAGE=$(EXECUTABLE).s19
HEX_IMAGE=$(EXECUTABLE).hex
ENTRY_TMP=entry.tmp

MODULES=sbmk3.o acia.o vectors.o

AS=ca65
ASFLAGS=--cpu 65c02 -I../include
LD=ld65
LDFLAGS=--config $(LD_CONFIG)

all: $(S19_IMAGE) $(HEX_IMAGE)

clean:
	-rm -f *.bin *.hex *.lbl *.lst *.map *.o *.s19 *.sym *.tmp

sbmk3.o: sbmk3.s basic.s
	$(AS) $(ASFLAGS) --feature labels_without_colons $< -o $@ -l $*.lst

acia.o: ../lib/acia.s
	$(AS) $(ASFLAGS) -DACIA_ISR_INCLUDED=1 -DACIA_HEAD=0xEC -DACIA_TAIL=0xED  $< -o $@ -l $*.lst

vectors.o: vectors.s
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
