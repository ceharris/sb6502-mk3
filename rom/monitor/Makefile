.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

IMAGE=monitor.bin
LD_CONFIG=monitor.cfg

INCLUDES=$(LD_CONFIG) \
        ../include/ascii.h.s  \
	../include/ansi.h.s \
	../include/acia.h.s \
	../include/ports.h.s \
	../include/prog.h.s \
	../include/stdio.h.s \
	registers.h.s

MODULES=monitor.o acia.o stdio.o registers.o vectors.o

AS=ca65
LD=ld65

ASFLAGS=--cpu 65c02 -I ../include -DACIA_ISR_INCLUDED=1
LDFLAGS=--config $(LD_CONFIG)

all: $(IMAGE)

clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

monitor.o: monitor.s $(INCLUDES)
registers.o: registers.s $(INCLUDES)
acia.o: ../lib/acia.s $(INCLUDES)
stdio.o: ../lib/stdio.s $(INCLUDES)
vectors.o: vectors.s $(INCLUDES)

$(IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

%.o: */%.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
