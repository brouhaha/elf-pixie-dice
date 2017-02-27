; COSMAC Elf program for dice using PIXIE display
; Copyright 2017 Eric Smith <spacewar@gmail.com>

; This program is free software: you can redistribute it and/or modify
; it under the terms of version 3 of the GNU General Public License
; as published by the Free Software Foundation.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.

; This source file is intended to assemble with the
; Macro Assembler AS:
;   http://john.ccac.rwth-aachen.de:8000/as/

	cpu	1802

dmareg	equ	0	; r0:  DMA pointer
intpc	equ	1	; r1:  interrupt program counter
sp	equ	2	; r2:  stack pointer
mainpc	equ	3	; r3:  main program counter
decpc	equ	4	; r4:  die to bitmap subroutine program counter


dbase	equ	8	; r8.0:  die base bitmap pointer
bitmap	equ	9	; r9:    working bitmap pointer
die	equ	10	; r10.0: die being updated in display
tptr	equ	11	; r11:   die pattern table pointer

dice	equ	14	; r14.0: left die,  one-hot, bits 0-5
			; r14.1: right die, one-hot, bits 0-5

rowcnt	equ	15	; r15: pixel row counter

; ----------------------------------------------------------------------

; initialization

reset:	ghi	dmareg

	plo	sp		; sp = 0x??00
	dec	sp		; sp = 0x??ff

; for an Elf with only 256 bytes of RAM (undecoded), the following
; sequence of phi instructions could be omitted
	phi	sp		; sp = 0x00ff
	phi	intpc
	phi	mainpc
	phi	decpc
	phi	dbase
	phi	bitmap
	phi	tptr

	ldi	main&0ffh	; main program
	plo	mainpc
	
	ldi	decode&0ffh	; decode subroutine
	plo	decpc

	ldi	int&0ffh	; interrupt program counter
	plo	intpc

	ldi	01h		; start dice both as 1 (snake eyes)
	plo	dice		; left die
	phi	dice		; right die

	sep	3		; switch to main program counter,
				; to free R0 up for display DMA

main:	inp	1		; enable PIXIE

; ----------------------------------------------------------------------

; main loop

mainlp:
; update display bitmap for left die
	glo	dice
	plo	die
	ldi	dismem		; frame buffer, no offset (left side)
	plo	dbase

	sep	decpc		; call die-to-pixel decoder

; update display bitmap for right die
	ghi	dice
	plo	die
	ldi	dismem+4	; frame buffer, offset of 4 (right side)
	plo	dbase

	sep	decpc		; call die-to-pixel decoder

	bn4	mainlp		; if INPUT button not pressed, done

; roll left die
roll:	glo	dice
	shr
	bnf	roll1
	ldi	20h
roll1:	plo	dice
	bnf	mainlp

; roll right die (if left die wrapped around)
	ghi	dice
	shr
	bnf	roll2
	ldi	20h
roll2:	phi	dice
	br	mainlp

; ----------------------------------------------------------------------

decrtn:	sep	mainpc

; subroutine to update display bitmap for a die
; on entry, die.0 contains the one-hot die value (bits 0..5)
;           dbase contains the base bitmap pointer for the die
;                (bitmap + 0) for left, (bitmap + 4) for right
decode:
	ldi	table & 0ffh
	plo	tptr

	sex	tptr

dloop:
; first byte of a table entry is offset into display bitmap, or 0 for end
	ldx			; end of table (first byte zero?)
	bz	decrtn

	glo	dbase
	add
	plo	bitmap
	irx

; second byte of a table entry is the mask of digit values to enable pixel
	glo	die
	and
	irx

	bnz	pixel1
	ldxa
	irx
	br	pixel

pixel1:	irx
	ldxa

pixel:	str	bitmap

	br	dloop

; ----------------------------------------------------------------------

intret:
	ldxa		; restore D
	ret		; return, restoring X and P, and reenabling interrupt

; PIXIE display interrupt routine

int:	nop			;  0- 2  3 cyc instr for pgm sync

	dec	sp		;  3- 4  t -> stack
	sav			;  5- 6

	dec	sp		;  7- 8  d -> stack
	str	sp		;  9-10

	ldi	numl		; 11-12  set line counter
	plo	rowcnt		; 13-14

	if	0
; setting high byte of dmareg (R0) unnecessary, it's already 0
	ldi	dismem>>8	; 15-16
	phi	dmareg		; 17-18
	else
	sex	sp		; 15-16  no-op
	sex	sp		; 17-18  no-op
	endif

	ldi	dismem&0ffh	; 19-20
	plo	dmareg		; 21-22

disp:	glo	dmareg		; 23-24  save pointer to start of this line
	sex	sp		; 25-26  no-op
	sex	sp		; 27-28  no-op
; display 0th pixel row

	plo	dmareg
	sex	sp	; no-op
	sex	sp	; no-op
; display 1st pixel row

	plo	dmareg
	sex	sp	; no-op
	sex	sp	; no-op
; display 2nd pixel row

	plo	dmareg
	sex	sp	; no-op
	sex	sp	; no-op
; display 3rd pixel row

	plo	dmareg
	sex	sp	; no-op
	sex	sp	; no-op
; display 4th pixel row

	plo	dmareg
	sex	sp	; no-op
	sex	sp	; no-op
; display 5th pixel row

	plo	dmareg
	dec	rowcnt
	sex	sp	; no-op
; display 6th pixel row

	plo	dmareg
	glo	rowcnt
	bnz	disp
; display 7th pixel row (even if the above bnz is taken)

; display blank rows until PIXIE drives EF1 high
	glo	dmareg

blank1:	plo	dmareg
	bn1	blank1

blank2:	plo	dmareg
	b1	blank2

	br	intret

; ----------------------------------------------------------------------

; bitmap update table
; five entries, each having bytes (in order)
;    offset into display bitmap (add 04h for right die)
;    bitmap of digits for which pixel is set
;    display bitmap byte if pixel is off
;    display bitmap byte if pixel is on
table:	db	010h,038h,0c0h,0c3h	; top    left,   4-6
	db	012h,03eh,000h,030h	; top    right,	 2-6
	db	020h,020h,0c0h,0c3h	; middle left,   6
	db	021h,015h,000h,00ch	; middle middle, 1,3,5
	db	022h,020h,000h,030h	; middle left,   6
	db	030h,03eh,0c0h,0c3h	; bottom left,   2-6
	db	032h,038h,000h,030h	; bottom right,  4-6
	db	000h

; ----------------------------------------------------------------------

; display frame buffer
; eight bytes per display line (64 pixels)
; initially only contains die outlines; pips will be
; added at runtime

dismem:	db	0ffh,0ffh,0ffh,0c0h,0ffh,0ffh,0ffh,0c0h
	db	0c0h,000h,000h,0c0h,0c0h,000h,000h,0c0h
	db	0c0h,000h,000h,0c0h,0c0h,000h,000h,0c0h
	db	0c0h,000h,000h,0c0h,0c0h,000h,000h,0c0h
	db	0c0h,000h,000h,0c0h,0c0h,000h,000h,0c0h
	db	0c0h,000h,000h,0c0h,0c0h,000h,000h,0c0h
	db	0c0h,000h,000h,0c0h,0c0h,000h,000h,0c0h
	db	0c0h,000h,000h,0c0h,0c0h,000h,000h,0c0h
	db	0ffh,0ffh,0ffh,0c0h,0ffh,0ffh,0ffh,0c0h

numl	equ	($-dismem)/8

; blank line used for remainder of display:
	db	000h,000h,000h,000h,000h,000h,000h,000h
