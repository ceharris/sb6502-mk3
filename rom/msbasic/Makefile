.PHONY: all clean
.SUFFIXES: .bin .lbl .lst .map .o .s .sym

INCLUDES=msbasic.cfg ../include/jmptab.h.s

SOURCES=array.s chrget.s defines.s error.s eval.s extra.s float.s flow1.s flow2.s \
	init.s inline.s input.s iscntc.s loadsave.s macros.s memory.s message.s misc1.s \
        misc2.s msbasic.s poke.s print.s program.s rnd.s string.s token.s trig.s \
        var.s zeropage.s defines_sbmk3.s sbmk3_extra.s sbmk3_iscntc.s 

AS=ca65
LD=ld65

ASFLAGS=--cpu 65c02 -Dsbmk3 -I ../include
LDFLAGS=--config msbasic.cfg
IMAGE=msbasic.bin

all: $(IMAGE)

clean:
	-rm -f *.bin *.lbl *.lst *.map *.o *.sym

msbasic.o: $(SOURCES) $(INCLUDES)

$(IMAGE): msbasic.o
	$(LD) $(LDFLAGS) $^ -o $@ -m $*.map -Ln $*.lbl

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
	
