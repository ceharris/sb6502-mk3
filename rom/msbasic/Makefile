.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

IMAGE=msbasic.bin
LD_CONFIG=msbasic.cfg

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

all: $(IMAGE)

clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

msbasic.o: $(SOURCES) $(INCLUDES)

acia.o: ../lib/acia.s $(INCLUDES)
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

stdio.o: ../lib/stdio.s $(INCLUDES)
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst

$(IMAGE): $(MODULES)
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
