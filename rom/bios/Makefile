.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

INCLUDES=bios.cfg acia.h.s exec.h.s \
         ../include/ascii.h.s ../include/conf.h.s ../include/ports.h.s ../include/prog.h.s \
	 ../include/registers.h.s
MODULES=exec.o acia.o stdio.o vectors.o registers.o jmptab.o

AS=ca65
LD=ld65

ASFLAGS=--cpu 65c02 -I ../include
LDFLAGS=--config bios.cfg
IMAGE=bios.bin

all: $(IMAGE)

clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

acia.o: acia.s $(INCLUDES)
exec.o: exec.s $(INCLUDES)
jmptab.o: jmptab.s $(INCLUDES)
registers.o: registers.s $(INCLUDES)
stdio.o: stdio.s $(INCLUDES)
vectors.o: vectors.s $(INCLUDES)

$(IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
