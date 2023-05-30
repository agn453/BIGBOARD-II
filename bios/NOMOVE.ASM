	title 'Minimal bank & move module for CP/M3 linked BIOS'

;		+-----------------------+
;		|			|
;		|	M O V E		|
;		|			|
;		+-----------------------+
;
;           CP/M-80 Version 3  --  Modular BIOS
;
;		   Block move routines
;
;   Modification History:
;
;	27-Aug-1985	Tony Nicholson	Initial version
;
;
	public	?xmove,?move		; select move bank, and block move
	public	?bank			; select CPU bank

	maclib	Z80

;
;	M E M O R Y   B L O C K   M O V E
;
;  Memory move routine (referenced by BIOS jump vector)
;
;  Copies BC bytes from address in DE to address in HL
;

	CSEG	;Common memory

?move:
	XCHG
	LDIR
	XCHG
	RET

;
;	E X T E N D E D   M E M O R Y   M O V E   S E L E C T
;
;  Select banks for subsequent extended address memory move
;
;  Entry:	B = destination bank
;		C = source bank
;


?xmove:
	RET

;
;	S E L E C T   M E M O R Y   B A N K
;

?bank:
	RET

	END
