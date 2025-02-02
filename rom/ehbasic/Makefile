.PHONY: all clean
.SUFFIXES: .bin .o .lst .map .s .sym .lbl

IMAGE=ehbasic.bin
LD_CONFIG=ehbasic.cfg

AS=ca65
ASFLAGS=--cpu 65c02 -I../include
LD=ld65
LDFLAGS=--config $(LD_CONFIG)

all: ehbasic.bin

clean:
	-rm -f *.bin *.o *.lst *.map *.sym *.lbl

$(IMAGE): sbmk3.o acia.o vectors.o
	$(LD) $(LDFLAGS) $^ -vm -m $*.map -Ln $*.lbl -o $@ 

sbmk3.o: sbmk3.s basic.s
	$(AS) $(ASFLAGS) --feature labels_without_colons $< -o $@ -l $*.lst

acia.o: ../lib/acia.s
	$(AS) $(ASFLAGS) -DACIA_ISR_INCLUDED=1 -DACIA_HEAD=0xEC -DACIA_TAIL=0xED  $< -o $@ -l $*.lst

vectors.o: vectors.s
	$(AS) $(ASFLAGS) $< -o $@ -l $*.lst
