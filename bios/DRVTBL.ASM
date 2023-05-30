;	+-----------------------+
;	|			|
;	|      D R V T B L	|
;	|			|
;	+-----------------------+

	maclib	CONFIG
	public	@dtbl

  if hard$disk
	extrn	hddd0
	extrn	fddd0,fddd1
  else
	extrn	fddd0,fddd1,fddd2,fddd3
  endif

	cseg

@dtbl:
  if hard$disk
	dw fddd0,fddd1				; drives A-B are 8" floppies
	dw hddd0				; drive C is hard disk
	dw 0,0,0,0,0,0,0,0,0,0,0,0,0		; drives D-P non-existant
  else
	dw fddd0,fddd1,fddd2,fddd3
	dw 0,0,0,0,0,0,0,0,0,0,0,0		; drives E-P non-existant
  endif
	end
