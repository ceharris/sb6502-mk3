
PART1=ATF22V10C
PART2=ATF16V8C

GALAS=galette
PU=minipro

.PHONY: all clean
.SUFFIXES: .chp .fus .jed .pin .pld


all:  glue1.jed glue2.jed

chip1: glue1.jed
	$(PU) -p $(PART1) -uP -w $<

chip2: glue2.jed
	$(PU) -p $(PART2) -uP -w $<

clean:
	-rm -f *.chp *.fus *.jed *.pin

%.jed: %.pld
	$(GALAS) $<


