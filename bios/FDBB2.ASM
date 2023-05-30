	title 'FDBB2 Big Board II Double density diskette handler'

;		+-----------------------+
;		|			|
;		|	F D B B 2	|
;		|			|
;		+-----------------------+
;
;           CP/M-80 Version 3  --  Modular BIOS
;
;	    Disk I/O Module for Ferguson BB II
;	         based diskette systems
;
;   Modification History:
;
;	27-Aug-1985	Tony Nicholson	Initial version
;	30-Aug-1985	Tony Nicholson	Fix single density skew table
;	18-Nov-1985	Tony Nicholson	Use USERF BIOS entry for
;					enabling/disabling software
;					skewing of 1024 byte 8 sector
;					per track disks.
;	11-Jul-1986	Tony Nicholson	Double sided floppy disk
;					support code added. Note that
;					the double sided format is
;					NOT compatible with the DISK-1
;					and Disk Jockey 2D formats.
;	20-Jul-1986	Tony Nicholson	Reselect normal head in rw$common
;	21-Jan-1987	Tony Nicholson	Make public the ?geco routine
;	31-Mar-1987	Tony Nicholson	Add capability of reading IBM-PC/AT
;					formatted 1.2 Mbyte floppies
;

	maclib	CONFIG		;Configuration constants
	maclib	MEMDEF
	maclib	IOPORTS
	maclib	CPM3
	maclib	Z80

;
; *** Disk drive dispatching tables for linked BIOS
;
	public	fddd0,fddd1,fddd2,fddd3
	public	?phex,?phexm,?geco
	public	rd$msg,wr$msg,er$msg,op$name

  if skew$dd
	public	SKEWFL
	public	USERF
  endif

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
	extrn	?pderr		; print BIOS disk error header
	extrn	?conin,?cono	; con in and out
	extrn	?const		; get console status

  if ibm$at
    if not double$sided
      error	'IBM PC/AT support requires DOUBLE SIDED option true'
    endif
  endif

cr	equ	13
lf	equ	10
bell	equ	7


;
;	Maximum disk sector size
;
HSTSIZ	EQU	1024
DRM	EQU	128		;Maximum number of directory entries
DSM	EQU	674		;Maximum number of 2K blocks per drive
NTRAKS	EQU	77		;Number of tracks per surface

;
;	CP/M disk control block equates
;	which define the disk types
;
;	(Double sided and IBM-PC/AT format
;	 support are enabled in CONFIG.LIB)
;
DSKS1	EQU	0	;Single density 128, single sided (IBM 3740)
DSKS2	EQU	1	;Single density 128, double sided
DSKD1	EQU	2	;Double density 256, single sided (IBM System 34)
DSKD2	EQU	3	;Double density 256, double sided
DSKD3	EQU	4	;Double density 512, single sided
DSKD4	EQU	5	;Double density 512, double sided (IBM-PC/AT 1.2Mb)
DSKD5	EQU	6	;Double density 1024, single sided
DSKD6	EQU	7	;Double density 1024, double sided
DSKD7	EQU	8	;Double density 1024, single sided (9 sectors/track)
DSKD8	EQU	9	;Double density 1024, double sided

MAXFTP	EQU	DSKD8	;Maximum floppy type

;
;	Disk drive constants
;
STEPR	EQU	3		;Ye-data 3ms step
MRTRY	EQU	10		;Number of re-tries

;
; *** Extended Disk Parameter Headers (XPDHs)
;
	DSEG		; Banked memory

	dw	fd$write
	dw	fd$read
	dw	fd$login
	dw	fd$init0
	db	0		; relative drive zero
	db	dskd8		; disk type
fddd0:
  if ldrbios
	dw	0		; no sector translation
	db	0,0,0,0,0,0,0,0,0 ; 72 bit scratch
	db	0		; media flag
	dw	dpbd8		; dpb pointer
	dw	csv		; checksum vector
	dw	alv		; allocation vector
	dw	dirbcb
	dw	dtabcb
	dw	0ffffh
	db	0
  else
	dw	0		; no sector translation
	db	0,0,0,0,0,0,0,0,0 ; 72 bit scratch
	db	0		; media flag
	dw	dpbd8		; dpb pointer
	dw	0FFFEh		; checksum vector
	dw	0FFFEh		; allocation vector
	dw	0FFFEh
	dw	dtabcb
	dw	0ffffh
	db	0
  endif

	dw	fd$write
	dw	fd$read
	dw	fd$login
	dw	fd$init1
	db	1		; relative drive one
	db	dskd8		; disk type
fddd1:	dw	0		; no sector translation
	db	0,0,0,0,0,0,0,0,0 ; 72 bit scratch
	db	0		; media flag
	dw	dpbd8		; dpb pointer
	dw	0FFFEh		; checksum vector
	dw	0FFFEh		; allocation vector
	dw	0FFFEh
	dw	dtabcb
	dw	0ffffh
	db	0

	dw	fd$write
	dw	fd$read
	dw	fd$login
	dw	fd$init2
	db	2		; relative drive two
	db	dskd8		; disk type
fddd2:	dw	0		; no sector translation
	db	0,0,0,0,0,0,0,0,0 ; 72 bit scratch
	db	0		; media flag
	dw	dpbd8		; dpb pointer
	dw	0FFFEh		; checksum vector
	dw	0FFFEh		; allocation vector
	dw	0FFFEh
	dw	dtabcb
	dw	0ffffh
	db	0

	dw	fd$write
	dw	fd$read
	dw	fd$login
	dw	fd$init3
	db	3		; relative drive three
	db	dskd8		; disk type
fddd3:	dw	0		; no sector translation
	db	0,0,0,0,0,0,0,0,0 ; 72 bit scratch
	db	0		; media flag
	dw	dpbd8		; dpb pointer
	dw	0FFFEh		; checksum vector
	dw	0FFFEh		; allocation vector
	dw	0FFFEh
	dw	dtabcb
	dw	0ffffh
	db	0

;
; DPB - Disk Parameter Header blocks for each particular disk density
;

	CSEG		; DPB must be resident

DPBS1:		;Single density 128, single sided
	DPB	128,26,77,1024,64,2

DPBS2:		;Single density 128, double sided
	DPB	128,26,154,2048,128,2

DPBD1:		;Double density 256, single sided
	DPB	256,26,77,2048,128,2

DPBD2:		;Double density 256, double sided
	DPB	256,26,154,2048,128,2

DPBD3:		;Double density 512, single sided
	DPB	512,15,77,2048,128,2

  if ibm$at
DPBD4:		;Double density 512, double sided (IBM-AT format)
	DPB	512,15,160,2048,128,0
  else
DPBD4:		;Double density 512, double sided
	DPB	512,15,154,2048,128,2
  endif

DPBD5:		;Double density 1024, single sided
	DPB	1024,8,77,2048,128,2

DPBD6:		;Double density 1024, double sided
	DPB	1024,8,154,2048,128,2

DPBD7:		;Double density 1024, single sided (9 sectors)
	DPB	1024,9,77,2048,128,2

DPBD8:		;Double density 1024, double sided
	DPB	1024,9,154,2048,128,2

;
;	Physical Sector Translation Tables
;
XLTS:	skew	26,6,0		;Single density 128 byte
;XLTD1:	skew	26,9,0		;Double density 256 byte
;XLTD2:	skew	15,4,0		;Double density 512 byte
XLTD3:	skew	8,3,0		;Double density 1024 byte


	DSEG		; Banked memory

XTABLE:	DW	XLTS		;Single 128
	DW	0		;Double 256
	DW	0		;Double 512
	DW	0		;Double 1024
	DW	0		;Double 1024 (9 sectors/track)


;
; *** Disk I/O routines for standardized BIOS interface
;
; Initialization entry point.
;
;	called for first time initialization.
;
fd$init0:
	mvi	a,5		;Set 5 revolution drive ready
	sta	nrevs		; wait
	mvi	a,stepr		;And step rate
	sta	speed
fd$init1:
fd$init2:
fd$init3:
	ret

;
; This entry is called when a logical drive is about to
; be logged into for the purpose of density determination.
;
; It adjusts the parameters contained in the disk
; parameter header pointed at by <DE>
;
fd$login:
	push	d		; save XDPH pointer
	lda	@rdrv		; and fetch relative
	mov	c,a		; drive number to determine
	call	TREAD		; the disk type
	pop	d
	rnz			; return if couldn't determine type
	dcx	d		; Save disk type in
	stax	d		; XDPH
	inx	d
	mov	L,a		; and use it to form
	mvi	H,0		; the DPB address
	mov	b,h
	mov	c,l
	dad	h		; (17 bytes per DPB)
	dad	h
	dad	h
	dad	h
	dad	b
	lxi	b,DPBS1
	dad	b
	xchg			; Now DE=DPB address
	push	h		; and HL=DPH address
	lxi	b,12		; Compute DPH DPB address
	dad	b		; (12 byte offset)
	mov	m,e		; and store DPB address
	inx	h		; into DPH
	mov	m,d

  if skew$dd
	cpi	DSKD5		; Force 1024 byte/sector skew
	jrnz	noskew		; (for single sided 1024 byte
				;  eight sectors per track format)
	push	psw		; Save disk type and check
	lda	skewfl		; if skewing is enabled
	ora	a
	jrz	noskw2		; No, restore type and continue

	lxi	h,skewms	; Yes, print message
	call	?pmsg

	pop	psw
	lxi	d,XLTD3		; Set up soft sector translation
	pop	h
	mov	m,e
	inx	h
	mov	m,d
	ret

noskw2:	pop	psw
noskew:
  endif

  if ibm$at
	cpi	DSKD4		; IBM-PC/AT format 1.2 Mb ?
	jrnz	notibm		; No
	push	psw		; Yes, print message
	lxi	h,ibmatms
	call	?pmsg
	pop	psw
notibm:
  endif

	ani	11111110b	; Remove sided bit from type
	mov	e,a		; and form address of the
	mvi	d,0		; sector translation table
	lxi	h,XTABLE
	dad	d
	xchg
	pop	h		; HL = DPH address again
	ldax	d		; so fetch and store the
	mov	m,a		; translation table address
	inx	h		; in the DPH
	inx	d
	ldax	d
	mov	m,a
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

fd$read:
	xra	a
	lxi	h,rd$msg	; point at " Read " msg
	jr	rw$common


fd$write:
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
	lda	@rdrv
	mov	c,a
	call	MONITR+27	;select drive
	jrnz	hard$error

more$retries:
	mvi	a,mrtry		;Set retry count
FNL1:	sta	rtry		;Clear retry count
	lda	@trk		;Get cylinder number
	call	doseek		;Seek to proper track
	jrnz	FNL3		;If seek error
	lhld	@dma		;Get dma address
	lda	@sect		; and physical sector
	inr	a		;adjust to start from sector 1
	mov	c,a
	lda	rwflag
	ora	a
	jrnz	FNLWR
	call	MONITR+36	;read sector
	jr	FNL2
FNLWR:	call	MONITR+39	;write sector

FNL2:
  if double$sided
	push	psw
	mvi	a,SIDSEL+OFF	;reselect normal side
	out	PORT0
	pop	psw
  endif

	rz			;return if no error

	sta	disk$status	;save type I status
	ani	01000000b	;Check write protected
	jrz	FNL3		;No
	ori	02h		;Yes, return write protected
	ret

FNL3:	lda	rtry		;Get retry counter
	dcr	A
	jrnz	FNL1		;If not permanent error

	lda	@dtyp		;Check for media change
	push	psw
	lda	@rdrv
	mov	C,A
	call	TREAD		;Determine disk type
	mov	C,A		; and save it in C
	jrnz	FNL4		;Non-recoverable if not determined
	pop	psw		;Is it the same type?
	cmp	C
	jrz	FNL5		;Yes, must be non-recoverable
	ori	0FFh		;Media has changed
	ret
FNL4:	pop	psw

FNL5:	lda	@ermde		; suppress error message
	cpi	0FFh		; if BDOS is returning
	jrz	hard$error	; errors to application
;
; Had permanent error, print message like:
;
; BIOS Err on d: T-nn, S-mm, <operation> Status= xx, Retry ?
;
	call	?pderr		; print message header
	lhld	op$name
	call	?pmsg		; last function
	lxi	h,status$msg	; print " Status="
	call	?pmsg
	lxi	h,disk$status	; Dump status byte
	call	?phexm
	lxi	h,er$msg
	call	?pmsg		; print ", Retry (Y/N) ? "
	call	?geco		; get operator response
	cpi	'Y'
	jrz	more$retries 	; Yes, then retry 10 more times
hard$error:			; otherwise, return a
	xra	A		; Non-recoverable media
	ori	1		; error to the BDOS
	ret


rtry:	db	0


;
;	TREAD - Determine floppy disk type.
;
;	ENTRY	C = Selected drive.
;
;	Exit	Zbit set = no error
;		A = disk type (0-9)
;

TREAD:	mov	A,C
	call	MONITR+27	;Call rom SELECT routine
	jrz	TRD1		;If drive is ready
	ori	0FFh		;Clear zero flag for error
	ret

TRD1:
	mvi	A,2		;Seek to track two
	call	doseek		;Do seek
	rnz			;If error
	lxi	h,idbuff
	call	MONITR+42	;Read ID mark
	rnz
	lda	idbuff+6	;Get density byte
	ani	1		;mask
	rz			;Return if single density (type=0)
	lda	idbuff+3	;Get sector length
	ani	3
	add	a		;Multiply by 2

  if double$sided
	push	psw		;Save disk type
	mvi	a,SIDSEL+ON	;Select top side of disk
	out	PORT0
	lxi	h,idtop		;Read an ID mark from the
	call	readid		; top side
	jrnz	TRD8		;Jump if not formatted
	lxi	h,idbuff
	lxi	d,idtop		;Compare ID fields to each other
	call	exor1
	jrnz	TRD8		;Jump if track number not identical
	call	exor1
	cpi	1
	jrnz	TRD8		;Jump if side numbers not complementary
	call	exor2
	jrnz	TRD8		;Jump if sector lengths not identical
	call	exor3
	jrnz	TRD8		;Jump if densities not identical
	pop	psw		;It is double sided,
	ori	1		; so merge in two-sided bit
	push	psw
TRD8:	mvi	a,SIDSEL+OFF	;Switch back to regular side
	out	PORT0
	pop	psw
  endif

	cpi	DSKD5		;Are they 1024 byte sectors?
	jc	TRD2
  if double$sided
	ani	1		;Save two sided bit
	mov	h,a
  endif
	lda	idbuff+1	;Check for 9 sectors/track
	cpi	9*2
	jrz	TRD9
	mvi	a,DSKD5		;No, use 8x1024 byte sectors
	jr	TRD3
TRD9:
	mvi	a,DSKD7
TRD3:
  if double$sided
	ora	h		;Restore two sided bit
  endif
TRD2:
	cmp	A		;Set zero flag
	ret


;
;	Seek to specified Track/Sector
;
;	Entry	A = Track
;

DOSEEK:
	mvi	b,SIDSEL+OFF	;Default to side 0

  if ibm$at
	push	psw
	lda	@dtyp		;Check for IBM-AT fromat
	cpi	DSKD4
	jrnz	notat
	pop	psw		;Yes, compute side number
	push	psw
	ani	1
	jrz	ss
	mvi	b,SIDSEL+ON	;side 1
ss:	pop	psw
	rar			;adjust for cylinder
	jr	dosk1

notat:	pop	psw
  endif

  if double$sided
	cpi	NTRAKS		;Test if track is on the
	jrc	DOSK1		; other side
	mvi	b,SIDSEL+ON	;Must be side 1
	sui	NTRAKS
  endif

DOSK1:
	mov	c,a		;Put track number in <C>
	mov	a,b		;Select side
	out	PORT0
	jmp	MONITR+33	;Seek using rom routine


SIDSEL	equ	1		;Side selection bit
OFF	equ	0000b
ON	equ	1000b
PORT0	equ	0C8h		;Disk control latch

;
; *** Get console input, echo it, and shift to upper case
;
?geco:
	call	?const
	ora	a
	jrz	u$c1		; see if any char already struck
	call	?conin
	jr	?geco		; yes, eat it and try again
u$c1:
	call	?conin		; get a character
	push	psw
	mov	c,a
	call	?cono		; echo it
	pop	psw
	cpi	'a'
	rc
	sui	'a'-'A'		; make upper case
	ret

;
; *** Print byte at HL in hex
;
?phexm:	push	h
	push	b
	mov	a,m
	call	?phex
	mvi	c,' '
	call	?cono
	pop	b
	pop	h
	ret

?phex:	push	psw
	rrc
	rrc
	rrc
	rrc
	call	phexc
	pop	psw
phexc:	ani	0Fh
	adi	90h
	daa
	aci	40h
	daa
	mov	c,a
	jmp	?cono

  if double$sided

force	equ	0F510h		;BB II Monitor routine

selmux	equ	0CCh

readid:	call	ready		;clear disk controller
	jmp	0F3DDh

ready:	mvi	a,1		;check if drive is ready
	sta	inuse
	lda	selcpy
	out	selmux
	call	force
	bit	7,a
	ret

exor3:	inx	h
	inx	d
exor2:	inx	h
	inx	d
exor1:	ldax	d		;Compare ID fields @HL and @DE
	xra	m
	inx	h
	inx	d
	ret
  endif

  if skew$dd
;
; *** User defined function to enable/disable
;     software skewing of 1024 byte 8 sector
;     per track format.
;     Return with A register non zero if
;     skewing is currently enabled.
;
USERF:	lda	SKEWFL
	cma
	sta	SKEWFL
	ret
  endif
;
; *** Error message components
;
rd$msg:		db	', Rd',0
wr$msg:		db	', Wr',0
status$msg:	db	' Status=',0
er$msg:		db	' Retry? ',0

op$name:	dw	rd$msg

  if skew$dd
SKEWMS:		db	cr,lf,'[Skew]',cr,lf,0
SKEWFL:		db	0	;Initially no soft skew
  endif

  if ibm$at
IBMATMS:	db	cr,lf,'[PC/AT]',cr,lf,0
  endif

rwflag:
	DS	1		;Read/write flag
disk$status:
	DS	1		;Result status
idbuff:
	DS	8		;Track ID buffer

  if double$sided
idtop:
	DS	8		;Track ID buffer for top side
  endif

  if ldrbios
dirbcb:	db	0ffh
	db	0,0,0
	db	0
	db	0
	dw	0
	dw	0
	dw	dirbuf
	db	0
	dw	0

dirbuf:	ds	1024

csv:	ds	(drm/4)+1

alv:	ds	(dsm/4)+2
  endif

dtabcb:	db	0ffh
	db	0,0,0
	db	0
	db	0
	dw	0
	dw	0
	dw	FD$DATBUF
	db	0
	dw	0


	end
