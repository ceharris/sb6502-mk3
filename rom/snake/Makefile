.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

IMAGE=snake.bin
LD_CONFIG=snake.cfg
INCLUDES=$(LD_CONFIG) serial.h.s state.h.s ui.h.s ../include/ascii.h.s  ../include/ports.h.s
MODULES=snake.o serial.o ui.o

AS=ca65
ASFLAGS=--cpu 65c02 -I ../include
LD=ld65
LDFLAGS=--config $(LD_CONFIG)

all: $(IMAGE)

clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

snake.o: snake.s $(INCLUDES)

serial.o: serial.s $(INCLUDES)

ui.o: ui.s $(INCLUDES)

$(IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -vm -m $*.map -Ln $*.lbl

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
