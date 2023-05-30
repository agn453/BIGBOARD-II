	title	'Root module of relocatable BIOS for CP/M 3.0'
;
;		+-----------------------+
;		|			|
;		|    B I O S K R N L	|
;		|			|
;		+-----------------------+
;
;		  Copyright (C), 1982
;		 Digital Research, Inc
;		     P.O. Box 579
;		Pacific Grove, CA  93950
;
;
;   This is the invariant portion of the modular BIOS and is
;	distributed as source for informational purposes only.
;	All desired modifications should be performed by
;	adding or changing externally defined modules.
;	This allows producing "standard" I/O modules that
;	can be combined to support a particular system 
;	configuration.
;
;   Modification History:
;
;	27-Aug-1985	Tony Nicholson	Compact code for Z80
;					and remove the configuation
;					equates to a seperate
;					CONFIG.LIB file.
;	18-Nov-1985	Tony Nicholson	Use USERF BIOS entry for
;					enabling/disabling software
;					skewing of 1024 byte 8 sector
;					per track disks.
;

	maclib	CONFIG		; Configuration constants
	maclib	MEMDEF		; Common memory definitions
	maclib	MODEBAUD	; Define serial I/O mode bits
	maclib	Z80		; Z80 instructions

cr	equ	13
lf	equ	10
bell	equ	7
ctlQ	equ	'Q'-'@'
ctlS	equ	'S'-'@'

ccp	equ	0100h	; Console Command Processor gets loaded into the TPA

	CSEG		; GENCPM puts CSEG stuff in common memory

;
; *** Variables in system data page
;
	extrn	@covec,@civec	; I/O redirection vectors
	extrn	@aovec,@aivec
	extrn	@lovec
	extrn	@mxtpa		; addr of system entry point
	extrn	@bnkbf		; 128 byte scratch buffer

;
; *** Initialization
;
	extrn	?init		; general initialization and signon
	extrn	?ldccp,?rlccp	; load & reload CCP for BOOT & WBOOT

;
; *** User defined character I/O routines
;
  if char$io
	extrn	?ci,?co
	extrn	?cist,?cost	; each take device in <B>
	extrn	?cinit		; (re)initialize device in <C>
	extrn	@ctbl		; physical character device table
  else
MONITR	equ	0F000h
  endif

;
; *** Disk communication data items
;
	extrn	@dtbl		; table of pointers to XDPHs
	public	@adrv,@rdrv	; parameters for disk I/O
	public	@trk,@sect
	public	@dma,@dbnk
	public	@cnt,@dtyp

  if skew$dd
	extrn	USERF
  endif
;
; *** Memory control
;
	public	@cbnk		; current bank
	extrn	?xmove,?move	; select move bank, and block move
	extrn	?bank		; select CPU bank

;
; *** Clock support
;
	extrn	?time		; signal time operation

;
; *** General utility routines
;
	public	?pmsg,?pdec	; print message, print number from 0 to 65535
	public	?pderr		; print BIOS disk error message header



;
; *** External names for BIOS entry points
;
	public	?boot,?wboot,?const,?conin,?cono,?list,?auxo,?auxi
	public	?home,?sldsk,?sttrk,?stsec,?stdma,?read,?write
	public	?lists,?sctrn
	public	?conos,?auxis,?auxos,?dvtbl,?devin,?drtbl
	public	?mltio,?flush,?mov,?tim,?bnksl,?stbnk,?xmov

	page
;
; *** BIOS Jump vector.
;
; All BIOS routines are invoked by calling these
;	entry points.

BIOS:
?boot:	jmp	boot	; initial entry on cold start
?wboot:	jmp	wboot	; reentry on program exit, warm start

?const:	jmp	const	; return console input status
?conin:	jmp	conin	; return console input character
?cono:	jmp	conout	; send console output character
?list:	jmp	list	; send list output character
?auxo:	jmp	auxout	; send auxilliary output character
?auxi:	jmp	auxin	; return auxilliary input character

?home:	jmp	home	; set disks to logical home
?sldsk:	jmp	seldsk	; select disk drive, return disk parameter info
?sttrk:	jmp	settrk	; set disk track
?stsec:	jmp	setsec	; set disk sector
?stdma:	jmp	setdma	; set disk I/O memory address
?read:	jmp	read	; read physical block(s)
?write:	jmp	write	; write physical block(s)

?lists:	jmp	listst	; return list device status
?sctrn:	jmp	sectrn	; translate logical to physical sector

?conos:	jmp	conost	; return console output status
?auxis:	jmp	auxist	; return aux input status
?auxos:	jmp	auxost	; return aux output status
?dvtbl:	jmp	devtbl	; return address of device def table
?devin:	jmp	?cinit	; change baud rate of device

?drtbl:	jmp	getdrv	; return address of disk drive table
?mltio:	jmp	multio	; set multiple record count for disk I/O
?flush:	jmp	flush	; flush BIOS maintained disk caching

?mov:	jmp	?move	; block move memory to memory
?tim:	jmp	?time	; Signal Time and Date operation
?bnksl:	jmp	bnksel	; select bank for code execution and default DMA
?stbnk:	jmp	setbnk	; select different bank for disk I/O DMA operations.
?xmov:	jmp	?xmove	; set source and destination banks for one operation

	jmp	userf	; reserved for system implementor
	jmp	reserv1	; reserved for future expansion
	jmp	reserv2	; reserved for future expansion

	page
;
; *** BOOT
;
;	Initial entry point for system startup.
;
	dseg		; this part can be banked

boot:
  if ldrbios
	sspd	boot$stack
  endif

	lxi	sp,boot$stack

  if not ldrbios and char$io
	mvi	c,15	; initialize all 16 character devices
c$init$loop:
	push	b
	call	?cinit
	pop	b
	dcr	c
	jp	c$init$loop
  endif

	call	?init	; perform any additional system initialization
			; and print signon message

	lxi	b,16*256+0
	lxi	h,@dtbl	; init all 16 logical disk drives
d$init$loop:
	push	b	; save remaining count and abs drive
	mov	e,m
	inx	h
	mov	d,m
	inx	h	; grab @drv entry
	mov	a,e	; if null, no drive
	ora	d
	jrz	d$init$next
	push	h	; save @drv pointer 
	xchg		; XDPH address in <HL>
	dcx	h
	dcx	h
	mov	a,m
	sta	@RDRV	; get relative drive code
	mov	a,c
	sta	@ADRV	; get absolute drive code
	dcx	h	; point to init pointer
	mov	d,m
	dcx	h
	mov	e,m	; get init pointer
	xchg
	call	ipchl	; call init routine
	pop	h	; recover @drv pointer
d$init$next:
	pop	b	; recover counter and drive #
	inr	c
	dcr	b	; and loop for each drive
	jrnz	d$init$loop
	jmp	boot$1

	cseg		; following in resident memory

boot$1:
	call	set$jumps
  if ldrbios
	lspd	boot$stack
	ret
  else
	call	?ldccp  ; fetch CCP for first time
	jr	goccp
  endif

;
; *** WBOOT
;
;	Entry for system restarts.
;
wboot:
  if not ldrbios
	lxi	sp,boot$stack
  endif
	call	set$jumps ; initialize page zero

  if ldrbios
	lspd	boot$stack
	ret
  else
	call	?rlccp  ; reload CCP
goccp:	jmp	ccp	; then reset jump vectors and exit to CCP
  endif


set$jumps:

  if banked
	mvi	a,1
	call	?bnksl
  endif

	mvi	a,JMP
	sta	0
	sta	5	; set up jumps in page zero
	lxi	h,?wboot
	shld	1	; BIOS warm start entry
  if not ldrbios
	lhld	@MXTPA
	shld	6	; BDOS system call entry
  endif
  if not skew$dd
userf:
  endif
reserv1:
reserv2:
	ret

;
; *** DEVTBL
;
;	Return address of character device table
;
devtbl:
	lxi	h,@ctbl
	ret

  if not char$io

@ctbl:	db	'CONSOL'
	db	3
	db	0
	db	0

  endif

;
; *** GETDRV
;
;	Return address of drive table
;
getdrv:
	lxi	h,@dtbl
	ret



;
; *** CONOUT
;
;	Console Output.  Send character in <C>
;			to all selected devices
;
conout:	

  if ldrbios or not char$io
	mov	a,c	; BB II monitor output
	jmp	MONITR+12
  else
	lhld	@covec	; fetch console output bit vector
	jr	out$scan
  endif

;
; *** AUXOUT
;
;	Auxiliary Output. Send character in <C>
;			to all selected devices
;
auxout:
  if char$io
	lhld	@aovec	; fetch aux output bit vector
	jr	out$scan
  else
	mov	a,c
	ret
  endif

;
; *** LIST
;
;	List Output.  Send character in <C>
;			to all selected devices.
;
list:
  if char$io
	lhld	@lovec	; fetch list output bit vector

out$scan:
	mvi	b,0	; start with device 0
co$next:
	dad	h	; shift out next bit
	jrnc	not$out$device
	push	h	; save the vector
	push	b	; save the count and character
not$out$ready:
	call	coster
	ora	a
	jrz	not$out$ready
	pop	b
	push	b	; restore and resave the character and device
	call	?co	; if device selected, print it
	pop	b	; recover count and character
	pop	h	; recover the rest of the vector
not$out$device:
	inr	b	; next device number
	mov	a,h
	ora	l 	; see if any devices left
	jrnz	co$next	; and go find them...
  else
	mov	a,c
  endif
	ret


;
; *** CONOST
;
;	Console Output Status.  Return true if
;		all selected console output devices
;		are ready.
;
conost:
  if ldrbios or not char$io
	ori	0ffh
	ret
  else
	lhld	@covec	; get console output bit vector
	jr	ost$scan
  endif


;
; *** AUXOST
;
;	Auxiliary Output Status.  Return true if
;		all selected auxiliary output devices
;		are ready.
;
auxost:
  if char$io
	lhld	@aovec	; get aux output bit vector
	jr	ost$scan
  else
	ret
  endif


;
; *** LISTST
;
;	List Output Status.  Return true if
;		all selected list output devices
;		are ready.
;
listst:
  if char$io
	lhld	@lovec	; get list output bit vector

ost$scan:
	mvi	b,0	; start with device 0
cos$next:
	dad	h	; check next bit
	push	h	; save the vector
	push	b	; save the count
	mvi	a,0FFh	; assume device ready
	cc	coster	; check status for this device
	pop	b	; recover count
	pop	h	; recover bit vector
	ora	a	; see if device ready
	rz		; if any not ready, return false
	inr	b	; drop device number
	mov	a,h
	ora	l 	; see if any more selected devices
	jrnz	cos$next
  endif
	ori	0FFh	; all selected were ready, return true
	ret

  if char$io
coster:		; check for output device ready, including optional
		;	xon/xoff support
	mov	l,b
	mvi	h,0	; make device code 16 bits
	push	h 	; save it in stack
	dad	h
	dad	h
	dad	h  	; create offset into device characteristics tbl
	lxi	d,@ctbl+6
	dad	d  	; make address of mode byte
	mov	a,m
	ani	mb$xonxoff
	pop	h  	; recover console number in <HL>
	jz	?cost	; not a xon device, go get output status direct
	lxi	d,xofflist
	dad	d	; make pointer to proper xon/xoff flag
	call	cist1	; see if this keyboard has character
	mov	a,m
	cnz	ci1	; get flag or read key if any
	cpi	ctlq
	jrnz	not$q	; if its a ctl-Q,
	mvi	a,0FFh 	;	set the flag ready
not$q:
	cpi	ctls
	jrnz	not$s	; if its a ctl-S,
	mvi	a,00h  	;	clear the flag
not$s:
	mov	m,a	; save the flag
	call	cost1 	; get the actual output status,
	ana	m	   	; and mask with ctl-Q/ctl-S flag
	ret	   	; return this as the status

cist1:			; get input status with <BC> and <HL> saved
	push	b
	push	h 
	call	?cist
pop$h$b$ret:
	pop	h
	pop	b
	ora	a
	ret

cost1:			; get output status, saving <BC> & <HL>
	push	b
	push	h
	call	?cost
	jr	pop$h$b$ret

ci1:			; get input, saving <BC> & <HL>
	push	b
	push	h
	call	?ci
	jr	pop$h$b$ret
  endif

;
; *** CONST
;
;	Console Input Status.  Return true if
;		any selected console input device
;		has an available character.
;
const:
  if char$io
	lhld	@civec	; get console input bit vector
	jr	ist$scan
  else
	jmp	MONITR+6
  endif


;
; *** AUXIST
;
;	Auxiliary Input Status.  Return true if
;		any selected auxiliary input device
;		has an available character.
;
auxist:
  if char$io
	lhld	@aivec	; get aux input bit vector

ist$scan:
	mvi	b,0	; start with device 0
cis$next:
	dad	h	; check next bit
	mvi	a,0	; assume device not ready
	cc	cist1	; check status for this device
	ora	a
	rnz		; if any ready, return true
	inr	b	; drop device number
	mov	a,h
	ora	l	; see if any more selected devices
	jrnz	cis$next
	xra	a	; all selected were not ready, return false
	ret
  else
	ori	0FFh
	ret
  endif


;
; *** CONIN
;
;	Console Input.  Return character from first
;		ready console input device.
;
conin:
  if char$io
	lhld	@civec
	jr	in$scan
  else
	jmp	MONITR+9
  endif


;
; *** AUXIN
;
;	Auxiliary Input.  Return character from first
;		ready auxiliary input device.
;
auxin:
  if char$io
	lhld	@aivec

in$scan:
	push	h	; save bit vector
	mvi	b,0
ci$next:
	dad	h	; shift out next bit
	mvi	a,0	; insure zero a  (nonexistant device not ready).
	cc	cist1	; see if the device has a character
	ora	a
	jrnz	ci$rdy	; this device has a character
	inr	b	; else, next device
	mov	a,h
	ora	l	; see if any more devices
	jrnz	ci$next	; go look at them
	pop	h	; recover bit vector
	jr	in$scan	; loop til we find a character

ci$rdy:
	pop	h	; discard extra stack
	jmp	?ci
  else
	mvi	a,1Ah
	ret
  endif


;
; *** Utility Subroutines
;

ipchl:		; vectored CALL point
	pchl


?pmsg:		; print message @<HL> up to a null
		; saves <BC> & <DE>
		; returns <HL> pointing to next
		; character following the null
	push	b
	push	d
pmsg$loop:
	mov	a,m
	inx	h
	ora	a
	jrz	pmsg$exit
	mov	c,a
	push	h
	call	?cono
	pop	h
	jr	pmsg$loop
pmsg$exit:
	pop	d
	pop	b
	ret

?pderr:
	lxi	h,drive$msg
	call	?pmsg	; error header
	push	h	; save pointer to track$msg
	lda	@adrv	; make drive code printable
	adi	'A'
	mov	c,a
	call	?cono	; drive code
	pop	h
	call	?pmsg	; track header
	push	h	; save pointer to sector$msg
	lhld	@trk
	call	?pdec	; track number
	pop	h
	call	?pmsg	; sector header
	lhld	@sect
			; fall through into ?pdec


?pdec:		; print binary number 0-65535 from <HL>

	lxi	b,-10	; get some useful constants
pdec1:	lxi	d,-1
pdec2:	dad	b	; subtract as many 10s as possible
	inx	d	; count them
	jrc	pdec2	; if some left, keep going
	push	h	; save remainder-10
	xchg		; swap the remainder and quotient
	mov	a,h	; get the number of 10s found
	ora	L	; check quotient for non-zero
	cnz	pdec1	; if non-zero, recurse
	pop	h	; get the remainder-10
	mov	a,L	; in A
	adi	'0'+10	; make the number printable and add the 10 back
	mov	c,a	; print it on the console
	jmp	?cono

;
; *** BNKSEL
;
;	Bank Select.  Select CPU bank for further execution.
;
bnksel:
	sta	@cbnk 	; remember current bank
	jmp	?bank	; and go exit through users
			; physical bank select routine

  if char$io
xofflist:	db	-1,-1,-1,-1,-1,-1,-1,-1		; ctl-s clears to zero
		db	-1,-1,-1,-1,-1,-1,-1,-1
  else
?cinit:	ret
  endif


	dseg		; following resides in banked memory


;
; *** Disk I/O interface routines
;

;
; *** SELDSK
;
;	Select Disk Drive.  Drive code in <C>.
;		Invoke login procedure for drive
;		if this is first select.  Return
;		address of disk parameter header
;		in <HL>
;
seldsk:
	mov	a,c
	sta	@adrv	; save drive select code
	mov	l,c
	mvi	h,0
	dad	h	; create index from drive code
	lxi	b,@dtbl
	dad	b	; get pointer to dispatch table
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a	; point at disk descriptor
	ora	h
	rz		; if no entry in table, no disk
	mov	a,e
	ani	1	; examine login bit and
	rnz		;  return if already selected
	push	h
	xchg		; put pointer to XDPH in <DE>
	lxi	h,-2
	dad	d
	mov	a,m
	sta	@RDRV	; get relative drive
	lxi	h,-6
	dad	d	; find LOGIN addr
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a	; get address of LOGIN routine
	call	ipchl	; call LOGIN
	pop	h	; recover DPH pointer
	ret

;
; *** HOME
;
;	Home selected drive.  Treated as SETTRK(0).
;
home:
	lxi	b,0	; same as set track zero


;
; *** SETTRK
;
;	Set Track. Saves track address from <BC> 
;		in @TRK for further operations.
;
settrk:
	sbcd	@trk
	ret


;
; *** SETSEC
;
;	Set Sector.  Saves sector number from <BC>
;		in @sect for further operations.
;
setsec:
	sbcd	@sect
	ret


;
; *** SETDMA
;
;	Set Disk Memory Address.  Saves DMA address
;		from <BC> in @DMA and sets @DBNK to @CBNK
;		so that further disk operations take place
;		in current bank.
;
setdma:
	sbcd	@dma

	lda	@cbnk	; default DMA bank is current bank
			; fall through to set DMA bank

;
; *** SETBNK
;
;	Set Disk Memory Bank.  Saves bank number
;		in @DBNK for future disk data
;		transfers.
;
setbnk:
	sta	@dbnk
	ret


;
; *** SECTRN
;
;	Sector Translate.  Indexes skew table in <DE>
;		with sector in <BC>.  Returns physical sector
;		in <HL>.  If no skew table (<DE>=0) then
;		returns physical=logical.
;
sectrn:
	mov	l,c
	mov	h,b
	mov	a,d
	ora	e
	rz
	dad	d
	mov	l,m
	mvi	h,0
	ret


;
; *** READ
;
;	Read physical record from currently selected drive.
;		Finds address of proper read routine from
;		extended disk parameter header (XDPH).
;
read:
	lhld	@adrv
	mvi	h,0
	dad	h	; get drive code and double it
	lxi	d,@dtbl
	dad	d	; make address of table entry
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a	; fetch table entry
	push	h	; save address of table
	lxi	d,-8
	dad	d	; point to read routine address
	jr	rw$common ; use common code


;
; *** WRITE
;
;	Write physical sector from currently selected drive.
;		Finds address of proper write routine from
;		extended disk parameter header (XDPH).
;
write:
	lhld	@adrv
	mvi	h,0
	dad	h	; get drive code and double it
	lxi	d,@dtbl
	dad	d	; make address of table entry
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a	; fetch table entry
	push	h	; save address of table
	lxi	d,-10
	dad	d	; point to write routine address

rw$common:
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a	; get address of routine
	pop	d	; recover address of table
	dcx	d
	dcx	d	; point to relative drive
	ldax	d
	sta	@rdrv	; get relative drive code and post it
	inx	d
	ldax	d		; also post drive type
	sta	@dtyp
	inx	d	; point to DPH again
	pchl		; leap to driver


;
; ***  MULTIO
;
;	Set multiple sector count. Saves passed count in
;		@CNT
;
multio:
	sta	@cnt
	ret


;
; *** FLUSH
;
;	BIOS deblocking buffer flush.  Not implemented.
;
flush:
	xra	a
	ret		; return with no error



;
; *** Error message components
;
;	 (Don't alter the order assumed by ?pderr)
;
drive$msg:	db	cr,lf,bell,'BIOS Error on ',0
track$msg:	db	': T-',0
sector$msg:	db	', S-',0


;
; *** Disk communication data items
;
@adrv:	ds	1	; currently selected disk drive
@rdrv:	ds	1	; controller relative disk drive
@trk:	ds	2	; current track number
@sect:	ds	2	; current sector number
@dtyp:	ds	1	; current disk type in drive
@cnt:	db	0	; record count for multisector transfer

;
; [ Do not change the order of @dma and @dbnk ]
;
@dma:	ds	2	; current DMA address
@dbnk:	db	0	; bank for DMA operations


	cseg	; common memory

@cbnk:	db	0	; bank for processor operations

	end
