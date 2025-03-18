.PHONY: all clean
.SUFFIXES: .bin .hex .lbl .lst .map .o .s .s19 .sym .tmp

EXECUTABLE=snake
LOAD_OFFSET=0xF000
EXECUTION_START_LABEL=start
LD_CONFIG=$(EXECUTABLE).cfg
BIN_IMAGE=$(EXECUTABLE).bin
S19_IMAGE=$(EXECUTABLE).s19
HEX_IMAGE=$(EXECUTABLE).hex
ENTRY_TMP=entry.tmp

INCLUDES=$(LD_CONFIG) delay.h.s display.h.s keys.h.s model.h.s prng.h.s \
	serial.h.s state.h.s timer.h.s ../include/ascii.h.s ../include/ports.h.s
MODULES=snake.o delay.o display.o keys.o model.o prng.o serial.o state.o \
	timer.o vectors.o

AS=ca65
ASFLAGS=--cpu 65c02 -I ../include
LD=ld65
LDFLAGS=--config $(LD_CONFIG)

all: $(S19_IMAGE) $(HEX_IMAGE)

clean:
	-rm -f *.bin *.hex *.lbl *.lst *.map *.o *.s19 *.sym *.tmp

delay.o: delay.s $(INCLUDES)
display.o: display.s $(INCLUDES)
keys.o: keys.s $(INCLUDES)
model.o: model.s $(INCLUDES)
prng.o: prng.s $(INCLUDES)
serial.o: serial.s $(INCLUDES)
snake.o: snake.s $(INCLUDES)
timer.o: timer.s $(INCLUDES)
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

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

%.o: ../lib/%.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

	
