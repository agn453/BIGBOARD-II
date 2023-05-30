	TITLE	'CLOCK routines for CP/M Plus V3.0'

;		+-----------------------+
;		|			|
;		|       C L O C K	|
;		|			|
;		+-----------------------+
;
;           CP/M-80 Version 3  --  Modular BIOS
;
;
;   Modification History:
;
;	28-Aug-1985	Tony Nicholson	Initial version
;
;	 3-Sep-85	RBD -- Big Board Clock interface

; Use the BB timer interrupt to update the SS|MM|HH bytes in the SCB

; When a clock set command is received, alter the BB clock interrupt
; vector to point to BIOS clock routine.


	PUBLIC	?CLKON,?TIME

	EXTRN	@HOUR, @SEC, @DATE


	maclib	Z80

TIKVEC	equ	0ff76h		; Timer interrupt vector in BB
TODTAB	equ	0f277h		; Table of max values for HH|MM|SS in BB
TIKCNT	equ	0ff85h		; BB timer tick down-counter

	DSEG	;Banked memory

?CLKON:	RET			; Used in Tony's startup
				; not needed for BB

;
;	BIOS CLOCK
;

	CSEG	;Common memory

?TIME:	mov	a,c		; Return if call
	ora	a		; is not a clock 'set'
	rz

	push	h		; Save register
	lxi	h,clock		; point to bios clock
	di
	shld	tikvec		; modify BB timer vector
	ei
	pop	h
	ret

; BB timer jumps here once (tikvec) is set
; The timer interrupt saves the registers

clock:	lda	tikcnt		; This routine never sees the counter at 0
	dcr	a		; as it is decremented & reset after this
	rnz			; routine is called

	lxi	d,@sec		; . to seconds in SCB
	lxi	h,todtab	; . to table of values in BB
	mvi	b,3		; set count

clock2:	ldax	d		; Get SS|MM|HH byte
	adi	1		; Use add to increment it so 
	daa			; AC flag is set for decimal adjust
	cmp	m		; Check maximum count against table
	jrc	clock3		;
	xra	a		; Reset the byte if max reached
clock3:	stax	d		; Save the new value
	rc			; No more to do if no reset

	dcx	d		; Adjust the
	inx	h		; Pointers
	djnz	clock2		; do next byte

; If code falls through to here then @hour has just been reset
; MIDNIGHT!
; So, increment @date

	lhld	@date
	inx	h
	shld	@date
	ret

	END
