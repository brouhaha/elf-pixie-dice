all: pdice.hex pdice.lst pdice.pdf

%.pdf: %.lst
	mpage -2 -l $< | ps2pdf - $@

%.p %.lst: %.asm
	asl -L +t 0xfc $<

%.hex: %.p
	p2hex $< $@

clean:
	rm -f *.p *.hex *.lst *.pdf
