	title 'Character I/O handler for Bigboard II system'

;		+-----------------------+
;		|			|
;		|     C H A R I O	|
;		|			|
;		+-----------------------+
;
;           CP/M-80 Version 3  --  Modular BIOS
;
;	 Character I/O for the Modular CP/M 3 BIOS
;
;
;   Modification History:
;
;	29-Aug-1985	Tony Nicholson	Initial version for BB II
;	17-Jun-1986	Tony Nicholson	Set default speed of SIOA
;					to 300 baud
;	03-Aug-1986	Tony Nicholson	Alter SIO initialization
;					to leave RTS on, DTR off
;
;
	maclib	CONFIG		; configuration info
	maclib	Z80		; define Z80 op codes
	maclib	IOPORTS		; define port addresses
	maclib	MODEBAUD	; define mode bits and baud equates
	maclib	MEMDEF

if char$io
	public	?cinit,?ci,?co,?cist,?cost
	public	@ctbl

max$devices	equ 4		; CONSOL, SIOA, SIOB, CENT

	CSEG		;All character I/O is in common memory

?cinit:
  if not ldrbios
	mov	a,c
	ora	a
	rz			; console device
	cpi	max$devices-1
	rnc			; invalid device
	rz			; no init required for CENTRONICS
	lxi	h,CONNUM	; check which console is booted
	cmp	m
	rz			; return if BB II monitor console
	mov	l,c
	mvi	h,0	 	; make 16 bits from device number
	push	h	 	; save device in stack
	dad	h
	dad	h
	dad	h	 	; *8 
	lxi	d,@ctbl+7
	dad	d
	mov	l,m	 	; get baud rate
	mov	a,l
	cpi	baud$300	; see if baud < 300
	mvi	a,44h
	jrnc	hi$speed  	; if >= 300, use *16 mode
	mvi	a,0C4h		;    else, use *64 mode
hi$speed:
	sta	sio$reg$4	
	mvi	h,0
	lxi	d,speed$table
	dad	d	  	; point to counter entry
	mov	a,m
	sta	speed$div	; get and save ctc count
	pop	h	  	; recover 
	lxi	d,data$ports
	dad	d	  	; point at SIO port address
	mov	a,m
	inr	a
	sta	sio$port  	; get and save status port addr
	lxi	d,baud$ports-data$ports
	dad	d	  	; offset to baud rate port
	mov	a,m
	sta	ctc$port  	; get and save
	lxi	h,serial$init$tbl

stream$out:
	mov	a,m
	ora	a
	rz
	mov	b,a
	inx	h
	mov	c,m
	inx	h
	outir
	jr	stream$out
  else
	ret
  endif

?ci:		; character input

  if ldrbios
	jmp	MONITR+9
  else
	mov	a,b
	ora	a
	jz	MONITR+9	; console device
	cpi	max$devices-1
	jrz	null$input	; cannot input from CENTRONICS
	jrnc	null$input 	; illegal device
	push	h
	lxi	h,CONNUM	; check if BB II rom
	cmp	m		; console
	pop	h
	jz	MONITR+9
ci1:
	call	?cist
	jrz	ci1	  	; wait for character ready

	dcr	c		; point to data register
	inp	a	  	; and get data
	ret

null$input:
	mvi	a,1Ah		; return a ctl-Z for no device
	ret
  endif

?cist:		; character input status

  if ldrbios
	jmp	MONITR+6
  else
	mov	a,b
	ora	a
	jz	MONITR+6	; console
	cpi	max$devices-1
	jrz	null$status	; cannot get input status from CENTRONICS
	jrnc	null$status	; illegal device
	lxi	h,CONNUM
	cmp	m
	jz	MONITR+6
	mov	l,b
	mvi	h,0		; make device number 16 bits
	lxi	d,data$ports
	dad	d		; make pointer to port address
	mov	c,m
	inr	c		; get SIO status port
	inp	a		; read from status port
	ani	SIODAV		; isolate RxRdy
	rz			; return with zero
	ori	0FFh
	ret

null$status:
	xra	a		; return not ready
	ret
  endif

?co:		; character output
  if ldrbios
	mov	c,a
	jmp	MONITR+12
  else
	mov	a,b
	ora	a
comon:	mov	a,c		; get character
	jz	MONITR+12	; console
	mov	a,b
	cpi	max$devices-1
	jrz	parallel$out
	jrnc	null$output
	push	h
	lxi	h,CONNUM
	cmp	m
	pop	h
	jrz	comon
	mov	a,c		; get character
	push	psw		; save character from <C>
	push	b		; save device number
co$spin:
	call	?cost
	jrz	co$spin		; wait for TxEmpty
	pop	h
	mov	l,h
	mvi	h,0		; get device number in <HL>
	lxi	d,data$ports
	dad	d		; make address of port address
	mov	c,m		; get port address
	pop	psw
	outp	a		; send data
null$output:
	ret
  endif

parallel$out:
	call	parallel$st	; check for printer ready
	jrz	parallel$out

	mov	a,c		; move character to a
	setb	7,a		; leave strobe off
	out	dataport
	res	7,a		; set strobe
	out	dataport
	setb	7,a		; ..and turn strobe off again
	out	dataport
	ret


?cost:		; character output status
  if not ldrbios
	mov	a,b
	ora	a
	jrz	console$ready
	cpi	max$devices-1
	jrz	parallel$st
	jrnc	null$status
	lxi	h,CONNUM
	cmp	m
	jrz	console$ready
	mov	l,b
	mvi	h,0
	lxi	d,data$ports
	dad	d
	mov	c,m
	inr	c 
	inp	a		; get input status
	ani	SIOTBE
	rz			; test transmitter empty
  endif
console$ready:
	ori	0FFh
	ret			; return true if ready

statport	equ	genpio+1
dataport	equ	genpio+3
rdyflag		equ	04h	; /ODVA1/ =bit 3

parallel$st:
	in	statport	; read status port
	ani	rdyflag		; check /ODAV/
	rz			; 0 means not ready
	ori	0ffh	
	ret


  if not ldrbios

baud$ports:		; CTC ports by physical device number

	db	0,CTCB,CTCA

data$ports:		; serial base ports by physical device number
	db	0,SIO0,SIO1

  endif

@ctbl:
	db	'CONSOL'	; device 0, BB II monitor console
	db	mb$in$out
	db	baud$none

	db	'SIOA  '	; device 1, SIO port A
	db	mb$in$out+mb$serial+mb$soft$baud+mb$xon$xoff
	db	baud$300

	db	'SIOB  '	; device 2, SIO port B
	db	mb$in$out+mb$serial+mb$soft$baud+mb$xon$xoff
	db	baud$4800

	db	'CENT  '	; device 3 CENTRONICS output
	db	mb$output
	db	0

	db	0		; table terminator

  if not ldrbios
;			  none,    50,    75,   110, 134.5,   150,   300
speed$table:	db	     0,   192,   128,    87,    71,    64,   128
;			   600,  1200,  1800,  2400,  3600,  4800,  7200
		db	    64,    32,    24,    16,    12,     8,     6
;			  9600, 19200
		db	     4,     2

serial$init$tbl:
		db	2	; two bytes to CTC
ctc$port:	ds	1	; port address of CTC
		db	47h	; CTC mode byte
speed$div:	ds	1	; baud multiplier

		db	6	; six bytes to SIO
sio$port:	ds	1	; port address of SIO status register
		db	4	; WR4 is clock divisor and stop bits
sio$reg$4:	ds	1
		db	3,0C1h	; WR3 is Rx enable, 8 bits/char
		db	5,06Ah 	; WR5 is Tx enable, 8 bits/char, RTS on, DTR off

		db	0	; terminator
  endif

endif ; char$io

	end
