.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

INCLUDES=monitor.cfg \
         ../include/ascii.h.s  ../include/ports.h.s
MODULES=monitor.o registers.o

AS=ca65
LD=ld65

ASFLAGS=--cpu 65c02 -I ../include
LDFLAGS=--config monitor.cfg
IMAGE=monitor.bin

all: $(IMAGE)

clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

monitor.o: monitor.s $(INCLUDES)

registers.o: registers.s $(INCLUDES)

$(IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
