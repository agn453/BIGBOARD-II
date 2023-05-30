	title	'Boot loader module for CP/M 3.0'

;		+-----------------------+
;		|			|
;		|	B O O T		|
;		|			|
;		+-----------------------+
;
;           CP/M-80 Version 3  --  Modular BIOS
;
;		  CCP Loader routines
;
;
;   Modification History:
;
;	28-Aug-1985	Tony Nicholson	Initial version
;	30-Aug-1985	Tony Nicholson	Copy CCP.COM from EPROM
;	18-Nov-1985	Tony Nicholson	Use USERF BIOS entry for
;					enabling/disabling software
;					skewing of 1024 byte 8 sector
;					per track disks.
;	18-Jun-1986	Tony Nicholson	Include SIO external status
;					interrupt enable so that
;					these bits can be checked
;					by routines polling the SIO
;					status registers.
;	11-Jul-1986	Tony Nicholson	Double sided floppy disk
;					support code added.
;	14-Jul-1986	Tony Nicholson	Add hard disk signon message
;	17-Jul-1986	Tony Nicholson	Fix external status SIO interrupt
;					routine to read the RR0 register
;					then clear the interrupt.
;	31-Mar-1987	Tony Nicholson	Add capability of reading IBM-PC/AT
;					formatted 1.2 Mbyte floppies
;	15-May-1987	Tony Nicholson	Support for TM503 hard disk.
;	20-Jul-1987	Tony Nicholson	Relocate boot$stack into common
;					memory and make SIO status
;					routines conditional on the
;					setting of serial$status
;	03-Dec-1987	Tony Nicholson	Support for Miniscribe 3425 hard disk.
;	04-Dec-1987	Tony Nicholson	Control byte to set hard disk step rate
;

	public	?init,?ldccp,?rlccp
	extrn	?pmsg,?conin
	extrn	@civec,@covec,@aivec,@aovec,@lovec
	extrn 	@cbnk,?bnksl,?clkon

	maclib	CONFIG
	maclib	IOPORTS
	maclib	MEMDEF
	maclib	Z80

cr	equ	13
lf	equ	10
bdos	equ	5

	if banked
tpa$bank equ	1
	else
tpa$bank	equ 0
	endif

;
; *** ?INIT
;
	dseg	; init done from banked memory

?init:
  if char$io
	lxi	h,08000h
	shld	@covec	; console output is CONSOL:
	shld	@civec	; console input is CONSOL:
	lxi	h,04000h
	shld	@aivec
	shld	@aovec	; AUX is SIOA:
	lxi	h,02000h
	shld	@lovec 	; printer is SIOB:
    if serial$status
	call	sio$status$inten
    endif
  else
	lxi	h,08000h
	shld	@covec
	shld	@civec
	lxi	h,0
	shld	@aivec
	shld	@aovec
	shld	@lovec
  endif
	call	?clkon	; start real time clock
	lxi	h,signon$msg
	jmp	?pmsg	; print signon message

  if char$io and serial$status
;
;	*** Enable SIO external status interrupts
;
	dseg

sio$status$inten:

	lxi	h,CONNUM	;Get console device

	di			;No interruptions

	mvi	a,11010001b	;Select SIO0 WR1, reset ext status
	out	SIO0+SIOSTS
	mov	a,m		;Is console SIO0 ?
	cpi	1
	mvi	a,00000001b	;Load ext inten bit
	jrnz	sios01		;No, not console
	ori	00011000b	;Yes, merge Rx inten bits, parity no affect
sios01:	out	SIO0+SIOSTS

	mvi	a,11010001b	;Select SIO1 WR1, reset ext status
	out	SIO1+SIOSTS
	mov	a,m		;Is console SIO1 ?
	cpi	2
	mvi	a,00000101b	;Load ext inten, status affects vector bits
	jrnz	sios02		;No, not console
	ori	00011000b	;Yes, merge Rx inten bits, parity no affect
sios02:	out	SIO1+SIOSTS

	lxi	h,sio1$ext$int
	shld	SIOVEC+2	;SIO1 ext status int vector
	lxi	h,sio0$ext$int
	shld	SIOVEC+10	;SIO0 ext status int vector

	ei			;Allow interrupts
	ret

	cseg

sio0$ext$int:			;Interrupt handler for
	push	psw		; SIO0 ext status
	push	b
	mvi	c,SIO0+SIOSTS
	jr	reset$ext$int

sio1$ext$int:			;Interrupt handler for
	push	psw		; SIO1 ext status
	push	b
	mvi	c,SIO1+SIOSTS
reset$ext$int:
	inp	a		;Read and discard status from RR0

	mvi	a,00010000b	;Reset ext/status interrupt
	outp	a
	pop	b
	pop	psw
	ei
	reti
  endif

	cseg	; boot loading most be done from resident memory
	
;
; *** ?LDCCP
;
; This version of the boot loader loads the CCP from a file
; called CCP.COM on the system drive (A:).
;
?ldccp:
?rlccp:

  if ccp$in$rom

ccp$rom$addr equ 5000h		;U80 socket address

	lxi	h,0100h		;CCP.COM base address
	shld	base
	lxi	h,ccp$rom$addr

nextk:	lxi	d,fd$datbuf	;copy 1K to disk buffer
	lxi	b,fd$datsiz
	di			;No interruptions
	mvi	a,0		;Select EPROM bank
	out	sys1
	ldir
	mvi	a,8		;De-select EPROM bank
	out	sys1
	ei
	shld	rom		;save next rom address

	lxi	h,fd$datbuf	;now copy from disk
	lded	base		; buffer to tpa
	lxi	b,fd$datsiz
	ldir
	sded	base		;save next ccp address
	lhld	rom
	mov	a,h		;repeat until 4K transferred
	cpi	(ccp$rom$addr+1000h)/256
	jrnz	nextk
	ret

base:	ds	2
rom:	ds	2

  else
	xra	a
	sta	ccp$fcb+15 ; zero extent
	lxi	h,0
	shld	fcb$nr	; start at beginning of file
	lxi	d,ccp$fcb
	call	open	; open file containing CCP
	inr	a
	jrz	no$CCP	; error if no file...
	lxi	d,0100h
	call	setdma	; start of TPA
	lxi	d,128
	call	setmulti; allow up to 16k bytes
	lxi	d,ccp$fcb
	jr	read	; load the thing

no$CCP:			; here if we couldn't find the file
	lxi	h,ccp$msg
	call	?pmsg	; report this...
	call	?conin	; get a response
	jr	?ldccp	; and try again


;
; *** CP/M BDOS Function Interfaces
;
open:
	mvi	c,15
	jr	bdosgo	; open file control block

setdma:
	mvi	c,26
	jr	bdosgo	; set data transfer address

setmulti:
	mvi	c,44
	jr	bdosgo	; set record count

read:
	mvi	c,20
bdosgo:	jmp	bdos	; read records

  endif

signon$msg:	db	cr,lf,'BB2 CP/M+ BIOS '
		version
		db	cr,lf,'['

  if skew$dd
		db	' SKEW'
  endif

  if ccp$in$rom
		db	' ROM'
  endif

  if hard$disk
		db	' '
    if tm503
		db	'15Mb'
    endif
    if st506
		db	'5Mb'
    endif
    if ms3425
		db	'20Mb'
    endif
		db	'HD'
  endif

  if double$sided
		db	' 2SDD8"'
  endif

  if ibm$at
		db	' PC/AT'
  endif

  if serial$status
		db	' SIOSTS'
  endif

		db	' ]',cr,lf
		db	0

  if not ccp$in$rom
ccp$msg:	db	cr,lf,'BIOS Err on A: No CCP.COM',0


ccp$fcb:	db	1,'CCP     ','COM',0,0,0,0
		ds	16
fcb$nr:		db	0,0,0
  endif

	end
