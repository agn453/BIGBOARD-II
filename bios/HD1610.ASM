	title 'HD1610 Big Board II Hard disk handler'

;		+-----------------------+
;		|			|
;		|      H D 1 6 1 0	|
;		|			|
;		+-----------------------+
;
;           CP/M-80 Version 3  --  Modular BIOS
;
;	    Disk I/O Module for Ferguson BB II
;	         based hard disk systems
;
;   Modification History:
;
;	22-May-1986	Tony Nicholson	Version for 1610-3 controller
;	14-Jul-1986	Tony Nicholson	Increase to 1024 directory entries
;	21-Jan-1987	Tony Nicholson	Use external ?geco routine in FDBB2.ASM
;	15-May-1987	Tony Nicholson	Support for TM503 hard disk
;	03-Dec-1987	Tony Nicholson	Support for Miniscribe 3425 hard disk
;	04-Dec-1987	Tony Nicholson	Control byte to set hard disk step rate
;

	maclib	CONFIG		;Configuration constants
	maclib	MEMDEF
	maclib	IOPORTS
	maclib	CPM3
	maclib	Z80

;
; *** Disk drive dispatching tables for linked BIOS
;
	public	hddd0

;
; *** Variables containing parameters passed by BDOS
;
	extrn	@adrv,@rdrv
	extrn	@dma,@trk,@sect
	extrn	@dbnk,@dtyp,@cbnk

;
; *** System Control Block variables
;
	extrn	@ermde		; BDOS error mode

;
; *** Utility routines in standard BIOS
;
	extrn	?wboot		; warm boot vector
	extrn	?pmsg		; print message @<HL> up to 00, saves <BC> & <DE>
	extrn	?pdec		; print binary number in <A> from 0 to 99.
	extrn	?phex		; print hexadecimal number in A
	extrn	?pderr		; print BIOS disk error header
	extrn	?conin,?cono	; con in and out
	extrn	?const		; get console status
	extrn	?geco		; con in with echo
	extrn	rd$msg,wr$msg,er$msg,op$name


cr	equ	13
lf	equ	10
bell	equ	7

;

;
;  SASI STATUS BIT DEFINITIONS
;
CD	EQU	00100000B	;C/D BIT MASK
CMD	EQU	00100000B	;  COMMAND STATUS
DATA	EQU	00000000B	;  DATA STATUS

MSG	EQU	00001000B	;MSG BIT MASK
MESSAG	EQU	00001000B	;  MESSAGE STATUS

BUSY	EQU	00000010B	;BUSY BIT MASK

IO	EQU	00000001B	;I/O BIT MASK
INPUT	EQU	00000001B	;  WAITING FOR INPUT
OUTPUT	EQU	00000000B	;  WAITING FOR OUTPUT 

CHKSTS	EQU	00000010B	;CHECK STATUS MASK

SEL	EQU	3		;SASI SEL
RSTR	EQU	2		;SASI RST
ON	EQU	00001000B
OFF	EQU	00000000B

;
;	Maximum disk sector size
;
HSTSIZ	EQU	512
DRM	EQU	1024		;Maximum number of directory entries

  if tm503
HDCTRL	EQU	00001000b	;40usec buffered step
DSM	EQU	3901		;Maximum number of 4K blocks per drive
  endif				; 306 cylinders, 6 heads --> 15606 Kb

  if st506
HDCTRL	EQU	00000000b	;3msec step, non-buffered
DSM	EQU	1300		;Maximum number of 4K blocks per drive
  endif				; 153 cylinders, 4 heads --> 5202 Kb

  if ms3425
HDCTRL	EQU	00001000b	;40usec buffered step
DSM	EQU	5227		;Maximum number of 4K blocks per drive
  endif				; 615 cylinders, 4 heads --> 20910 Kb
;
;	Disk drive constants
;
MRTRY	EQU	10		;Number of re-tries

;
; *** Extended Disk Parameter Headers (XPDHs)
;
	DSEG		; Banked memory

	dw	hd$write
	dw	hd$read
	dw	hd$login
	dw	hd$init0
	db	0		; relative drive zero
	db	0		; disk type
hddd0:
	dw	0		; no sector translation
	db	0,0,0,0,0,0,0,0,0 ; 72 bit scratch
	db	0		; media flag
	dw	hddpb		; dpb pointer
	dw	0		; no checksum vector (permanent drive)
	dw	0FFFEh		; allocation vector
	dw	0FFFEh
	dw	dtabcb
	dw	0ffffh
	db	0

;
; DPB - Disk Parameter Header block
;

	CSEG		; DPB must be resident

HDDPB:
	DW	68		;# 128-BYTE SECTORS PER TRACK
	DB	5		;BLOCK SHIFT
	DB	00011111B	;BLOCK MASK
	DB	00000001B	;EXTENT MASK
	DW	DSM-1		;MAX BLOCK#
	DW	1023		;MAX DIRECTORY ENTRY#
	DB	11111111B	;ALLOCATION MASK MSB
	DB	00000000B	;'             ' LSB
	DW	8000h		;CHECK SIZE (NOT REMOVABLE MEDIA)
	DW	0		;RESERVED TRACKS

	DB	2		;DEBLOCK SHIFT COUNT
	DB	00000011B	;DEBLOCK MASK


	DSEG			; I/O routines in banked memory

;
; *** Disk I/O routines for standardized BIOS interface
;
; Initialization entry point.
;
;	called for first time initialization.
;
hd$init0:
  if hard$init
	mvi	A,RSTR+ON
	OUT	SASIST		;RESET SASI BUS CONTROLLER(S)
	mvi	B,25
RSTDLY:	DJNZ	RSTDLY		;  RST ACTIVE FOR > 25 uSEC
	mvi	A,RSTR+OFF
	OUT	SASIST

  if tm503 or ms3425
	lxi	h,DCBRDY	;SPECIFY DRIVE
	mvi	m,00001100b
	CALL	DOCMD

	lxi	h,DRVPRM
OUT8:	IN	SASIST
	ani	CD+IO
	cpi	DATA+OUTPUT
	jrnz	OUT8
	mvi	B,8
	mvi	C,SASI
	CALL	REQ
	outir			;OUTPUT DATA

	CALL	STATUS
	rnz			;ERROR DETECTED
  endif
	
	lxi	h,DCBRDY	;CHECK DRIVE READY
	mvi	m,00000000b
	CALL	DOCMD
	CALL	STATUS
	rnz			;ERROR DETECTED

	lxi	h,DCBRDY	;SEEK TO TRACK 0
	mvi	m,000000001b
	CALL	DOCMD
	CALL	STATUS

	ret
  else
	ret
  endif


;
; This entry is called when a logical drive is about to
; be logged into for the purpose of density determination.
;
; It adjusts the parameters contained in the disk
; parameter header pointed at by <DE>
;
hd$login:
	ret


;
; *** Disk READ and WRITE entry points.
;
; These entries are called with the following arguments:
;
; relative drive number in @rdrv (8 bits)
; absolute drive number in @adrv (8 bits)
; disk transfer address in @dma (16 bits)
; disk transfer bank	in @dbnk (8 bits)
; disk track address	in @trk (16 bits)
; disk sector address	in @sect (16 bits)
; disk type		in @dtyp (8 bits)
; pointer to XDPH in <DE>
;
; They transfer the appropriate data, perform retries
; if necessary, then return an error code in <A>
;

hd$read:
	xra	a
	lxi	h,rd$msg	; point at " Read " msg
	jr	rw$common

hd$write:
	ori	0FFh
	lxi	h,wr$msg	; point at " Write "

;
;
;	R W $ C O M M O N   --  Preform final transfer processing.
;
;	ENTRY	A = Operation code (0h=read, 0FFh=write )
;		HL = Address of operation type message

rw$common:
	shld	op$name		; save message for errors
	sta	rwflag

more$retries:
	push	d		;CREATE DISK ADDRESS BYTES FOR DCB
	lhld	@TRK		;calculate the sector address
	mov	d,h		; ( = track*17 + sector )
	mov	e,l
	dad	h		; *2
	dad	h		; *4
	dad	h		; *8
	dad	h		; *16
	dad	d		; *17
	pop	d
	lda	@SECT
	add	L
	mov	L,a
	jrnc	stadr
	inr	h
stadr:	xra	a
	sta	DCBHAD
	mov	a,h
	sta	DCBMAD		;STORE MIDDLE ADDRESS BYTE
	mov	a,L
	sta	DCBLAD		;STORE LOW ADDRESS BYTE
	mvi	a,1		;Only one sector
	sta	DCBNUM

	lxi	h,DCB		;Point to DCB

	lda	rwflag		;Read or Write?
	ora	a
	jrnz	dwin3

dwin2:	call	RD		;READ FROM WINCHESTER
	jr	dwin4
;
dwin3:	call	WRT		;WRITE TO WINCHESTER
;
dwin4:	CALL	STATUS		;GET STATUS BYTE
	rz			;EXIT IF NO ERRORS FROM SASI

	CALL	ERROR		;ELSE READ ERROR STATUS
	lda	@ermde		;SUPPRESS ERROR MESSAGE
	cpi	0FFh		; IF BDOS IS RETURNING
	jrz	hard$error	; ERRORS TO APPLICATION

	call	?pderr		;PRINT MESSAGE HEADER
	lhld	op$name
	call	?pmsg		;LAST FUNCTION
	lxi	h,status$msg
	call	?pmsg		;PRINT " SASI Status="
	lda	errbuf
	bit	7,a		;TEST IF ADDRESS FIELD IS APPLICABLE
	jrz	dwinx		;PRINT ONLY FIRST STATUS BYTE IF NOT
	res	7,a
	call	?phex
	lda	errbuf+1
	call	?phex
	lda	errbuf+2
	call	?phex
	lda	errbuf+3
dwinx:	call	?phex
	lxi	h,er$msg
	call	?pmsg		; print ", Retry (Y/N) ? "
	call	?geco		; get operator response
	cpi	'Y'
	jz	more$retries 	; Yes, then retry 10 more times
hard$error:			; otherwise, return a
	xra	A		; Non-recoverable media
	ori	1		; error to the BDOS
	ret			;RETURN PERMANENT ERROR TO CP/M
;
DCB:				;DEVICE CONTROL BLOCK
DCBCMD:	DB	0		; Command byte
DCBHAD:	DB	0		; High sector address and LUN
DCBMAD:	DB	0		; Middle sector address
DCBLAD:	DB	0		; Low sector address
DCBNUM:	DB	0		; Number of sectors to transfer
DCBCTL:	DB	HDCTRL		; Control byte

ERRBUF:	DB	0,0,0,0		;ERROR STATUS BUFFER
;
;
;
RD:
	mvi	m,00001000b	;Read command
	call	DOCMD
	lhld	@dma

INPSEC:	IN	SASIST
	ani	CD+IO
	cpi	DATA+INPUT
	jrnz	INPSEC
	lxi	b,SASI
	CALL	REQ
	INIR			;INPUT DATA
	INIR
	RET
;

;
;
;
WRT:
	mvi	m,00001010b	;Write command
	call	DOCMD
	lhld	@dma
;
OUTSEC:	IN	SASIST
	ani	CD+IO
	cpi	DATA+OUTPUT
	jrnz	OUTSEC
	lxi	b,SASI
	CALL	REQ
	outir			;OUTPUT DATA
	outir
	RET
;
;
;
DOCMD:	PUSH	h
	CALL	SELSASI		;SELECT CONTROLLER

WAIT0:	CALL	READY
	jrz	WAIT0

WAIT1:	IN	SASIST		;WAIT FOR COMMAND REQUEST
	ani	CD+IO
	cpi	CMD+OUTPUT
	jrnz	WAIT1

DOCMD1:	CALL	DESELCT
	CALL	REQ
	POP	h		;OUTPUT COMMAND TO CONTROLLER
	mvi	B,6
	mvi	C,SASI
	outir
	RET

;
;
REQ:	PUSH	h
	DI
	lxi	h,INUSE
	mov	A,m
	mvi	m,1
	EI
	PUSH	psw
	ora	A		;TEST IF FLOPPYS WERE SELECTED OR NOT
	lda	SELCPY
	jrz	REQ1
	ani	00001111B
REQ1:	PUSH	psw
	ori	00001111B	;SELECT SASI REQ/ACK HANDSHAKE FLIPFLOP
	OUT	SELMUX		; THROUGH DMA READY MULTIPLEXOR
	mvi	A,10001010B
	OUT	DMA		;PROGRAM DMA READY ACTIVE HIGH
REQ2:	mvi	A,10111111B
	OUT	DMA		;ISSUE READ-DMA-STATUS COMMAND
	IN	DMA
	BIT	1,A
	jrnz	REQ2		;LOOP TILL READY IS ACTIVE
	POP	psw
	OUT	SELMUX
	POP	psw
	sta	INUSE		;RESTORE IN-USE FLAG TO PREVIOUS STATE
	POP	h
	RET
;
;
STATUS:	IN	SASIST		;WAIT FOR STATUS
	ani	CD+IO
	cpi	CMD+INPUT
	jrnz	STATUS
	CALL	REQ
	IN	SASI		;READ STATUS BYTE
	PUSH	psw
WAIT3:	IN	SASIST		;NOW WAIT FROM MSG
	ani	CD+MSG+IO	; TO INDICATE OPERATION
	cpi	CMD+MESSAG+INPUT; COMPLETE
	jrnz	WAIT3
	CALL	REQ
	IN	SASI		;READ MESSAGE BYTE
WAIT4:	IN	SASIST
	ani	MSG		;WAIT UNTIL MSG GOES AWAY
	cpi	MESSAG
	jrz	WAIT4
	POP	psw
	ani	CHKSTS		;RETURN ERROR STATUS
	RET
;
;
READY:	PUSH	b
	lxi	b,0
RDY0:	IN	SASIST		;TEST IF SASI BUS IS READY
	ani	BUSY
	jrnz	RDY1		;IT IS READY, RETURN
	dcx	b
	mov	A,B
	ora	C
	jrnz	RDY0
	PUSH	h		;TIME-OUT, PRINT MESSAGE
	lxi	h,NRDYMS
	CALL	?PMSG
	POP	h
	mvi	A,BUSY
	cpi	BUSY		;RETURN Z-FLAG SET
RDY1:	POP	b
	RET
;
NRDYMS:	db	CR,LF,'SASI NRDY',0
;
;
SELSASI:
	mvi	A,00000001B	;SELECT CONTROLLER #1
	OUT	SASI

	mvi	A,SEL+ON
	OUT	SASIST
	mvi	B,50
SELDLY:	DJNZ	SELDLY		;  SEL ACTIVE FOR > 50 uSEC
	RET
;
;
DESELCT:
	mvi	A,SEL+OFF
	OUT	SASIST
	RET
;
;
ERROR:
	lxi	h,DCBRDY
	mvi	m,00000011b	;Request sense command
	CALL	DOCMD

SENSE1:	IN	SASIST		;WAIT FOR STATUS
	ani	CD+IO
	cpi	DATA+INPUT
	jrnz	SENSE1

	CALL	REQ
	lxi	h,ERRBUF
	mvi	B,4
	mvi	C,SASI
	INIR

	CALL	STATUS
	mvi	a,1		;RETURN PERMANENT ERROR INDICATION
	ora	a
	RET

DCBRDY:	DB	0,0,0,0,0,0

  if tm503
DRVPRM:
	DB	HIGH 306	;NUMBER OF CYLINDERS
	DB	LOW  306
	DB	06		;NUMBER OF HEADS
	DB	HIGH 128	;REDUCE WRITE CURRENT CYLINDER
	DB	LOW  128
	DB	HIGH  64	;WRITE PRECOMPENSATION CYLINDER
	DB	LOW   64
	DB	08		;MAXIMUM ECC BURST
  endif

  if ms3425
DRVPRM:
	DB	HIGH 615	;NUMBER OF CYLINDERS
	DB	LOW  615
	DB	04		;NUMBER OF HEADS
	DB	HIGH 615	;REDUCE WRITE CURRENT CYLINDER
	DB	LOW  615
	DB	HIGH 615	;WRITE PRECOMPENSATION CYLINDER
	DB	LOW  615
	DB	08		;MAXIMUM ECC BURST
  endif

;
; *** Error message components
;
status$msg:	db	' SASI Status=',0

;

rwflag:
	DS	1		;Read/write flag

dtabcb:	db	0ffh
	db	0,0,0
	db	0
	db	0
	dw	0
	dw	0
	dw	hd$datbuf
	db	0
	dw	0

	end
