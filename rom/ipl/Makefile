.PHONY: all clean pre
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

IMAGE=ipl.bin
LD_CONFIG=ipl.cfg

INCLUDES=$(LD_CONFIG) \
	loader.h.s \
	../include/acia.h.s \
        ../include/ascii.h.s \
	../include/conf.h.s \
	../include/hex.h.s \
	../include/ports.h.s \
	../include/prog.h.s

MODULES=ipl.o \
	loader.o \
	acia.o \
	hex.o \
	stdio.o \
	vectors.o

AS=ca65
LD=ld65

ASFLAGS=--cpu 65c02 -I ../include -DACIA_ISR_INCLUDED=1
LDFLAGS=--config $(LD_CONFIG)

all: pre $(IMAGE)

pre:
	-rm -f acia.o
clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

acia.o: ../lib/acia.s $(INCLUDES)
hex.o: ../lib/hex.s $(INCLUDES)
ipl.o: ipl.s $(INCLUDES)
loader.o: loader.s $(INCLUDES)
stdio.o: ../lib/stdio.s $(INCLUDES)
vectors.o: vectors.s $(INCLUDES)

$(IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

%.o: ../lib/%.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

