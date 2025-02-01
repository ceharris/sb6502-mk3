.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .s19 .sym

IMAGE=snake.bin
S19_IMAGE=snake.s19
S19_LOAD=0xE000
S19_START=0xE014
LD_CONFIG=snake.cfg
INCLUDES=$(LD_CONFIG) model.h.s serial.h.s state.h.s ui.h.s ../include/ascii.h.s  ../include/ports.h.s
MODULES=snake.o model.o serial.o state.o ui.o

AS=ca65
ASFLAGS=--cpu 65c02 -I ../include
LD=ld65
LDFLAGS=--config $(LD_CONFIG)

all: $(S19_IMAGE)

clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.s19 *.sym

model.o: model.s $(INCLUDES)

snake.o: snake.s $(INCLUDES)

serial.o: serial.s $(INCLUDES)

ui.o: ui.s $(INCLUDES)

$(S19_IMAGE): $(IMAGE)
	srec_cat $< -Binary -Offset $(S19_LOAD) -Output -Motorola -Execution_Start_Address=$(S19_START) >$@

$(IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -vm -m $*.map -Ln $*.lbl

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
