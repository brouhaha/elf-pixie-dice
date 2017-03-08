all: pdice.hex pdice.lst

%.p %.lst: %.asm
	asl -L +t 0xfc $<

%.hex: %.p
	p2hex $< $@

%.pdf: %.lst
	mpage -1 -m -W120 -L80 $< | ps2pdf - $@
#	mpage -2 -l $< | ps2pdf - $@

clean:
	rm -f *.p *.hex *.lst *.pdf
