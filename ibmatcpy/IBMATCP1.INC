function press_CR: boolean;
var
  response         : char;
begin
  writeln;
  write(' Press RETURN when ready ');
  while not KeyPressed do;
  read(kbd,response);
  if response = CR
    then
      begin
        writeln;
        press_CR := TRUE
      end
    else
      press_CR := FALSE
end;

function unsigned( i: integer ): real;
var
  x                : real;
begin
  x := i;
  if x < 0
    then x := x + 65536.0;
  unsigned := x
end;

function compress( st: Str80): Str80;

var
  i                : integer;
begin
  repeat
    i:= pos(' ', st);
    if i > 0
      then delete(st, i, 1)
  until i = 0;
  compress := st
end;

function pad( st: Str80; i : integer): Str80;
begin
  while length(st) < i do
    st := st + ' ';
  pad := st
end;

function uppercase( st: Str80 ): Str80;
var
  i                : integer;
begin
  for i:= 1 to length(st) do
    st[i] := upcase(st[i]);
  uppercase := st
end;

procedure select_cpm_disk;
begin
  bpb.bc := ord(cpm_disk)-ord('A');
  bpb.de := 1;
  bpb.fn := bios_seldsk;
  bdos(cpm_call_bios,addr(bpb));
end;

function cpm_version_ok: boolean;
begin
  if bdoshl(cpm_get_version) >= $30
    then cpm_version_ok := TRUE
    else cpm_version_ok := FALSE
end;

procedure DateTime(var day, month, year, hour, minute, second: byte);
var
  juldate          : integer;

  procedure JulToDay(Year: byte; JulDate: integer; var Month, Day: byte);
  { Convert CP/M Plus date word. }
  const
    DaysInMonth = '312831303130313130313031';
  var
    DayInMon,
    ResCode        : integer;
    Finished       : boolean;
  begin
    Month := 1;
    Finished := false;
    while not Finished do
      begin
        val(copy(DaysInMonth, pred(2*Month), 2), DayInMon, ResCode);
        if (Month = 2) then
          begin
            if ((Year mod 4) = 0) then DayInMon := DayInMon + 1
          end;
        if (JulDate <= DayInMon) then
          Finished := true
        else
          begin
            JulDate := JulDate - DayInMon;
            Month := Month + 1
          end
      end;
    Day := JulDate
  end;

  procedure CPMtoJulian(CPMdate: integer; var Year: Byte; var JulDate: integer);
  const
    BaseYear = 78;
  begin
    Year := CPMdate div 365;
    JulDate := (CPMdate mod 365) - ((Year+1) div 4);
    Year := Year + BaseYear
  end;

  procedure GetTimeAndDate(var Year: byte; var JulDate: integer; var Hour, Minute, Second: Byte);
  var
    TimeDate: record
                 DateInt: integer;
                 HourByte: byte;
                 MinByte: byte
              end;

    function BCDtoBIN(BCD: byte): byte;
    begin
      BCdtoBIN := 10 * (BCD div 16) + (BCD mod 16)
    end;

  begin
    Second := BCDtoBIN(BDos(cpm_date_time, Addr(TimeDate)));
    with TimeDate do
      begin
        Minute := BCDtoBIN(MinByte);
        Hour   := BCDtoBIN(HourByte);
        CPMtoJulian(DateInt, Year, JulDate)
      end
  end;

begin { procedure DateTime }
  gettimeanddate (year,juldate,hour,minute,second);
  jultoday (year,juldate,month,day);
end;

function file_date( word: integer ): Str9;
const
  months = 'JanFebMarAprMayJunJulAugSepOctNovDec';
var
  date             : Str9;
  y, m, d          : integer;
  digits           : string[4];
begin
  d := word mod 32;
  m := (word shr 5) mod 16;
  y := word shr 9;
  if (d in [1..31]) and (m in [1..12]) and (y in [0..119])
    then
      begin
        str(d+100:3,digits);
        date := copy(digits,2,2) + '-' + copy(months,m*3-2,3) + '-';
        str(y+1980:4,digits);
        file_date := date + copy(digits,3,2)
      end
    else
      file_date := 'dd-mmm-yy'
end;

function file_time( word: integer ): Str5;
var
  time             : Str5;
  h, m             : integer;
  digits           : string[3];
begin
  m := (word shr 5) mod 64;
  h := word shr 11;
  str(h+100:3,digits);
  time := copy(digits,2,2) + ':';
  str(m+100:3,digits);
  file_time := time + copy(digits,2,2)
end;

function date_file( dd, mm, yy: byte): integer;
begin
  date_file := ((yy - 80) shl 9) or (mm shl 5) or dd
end;

function time_file( hr, mn, sc: byte): integer;
begin
  time_file := (hr shl 11) or (mn shl 5) or (sc shr 1)
end;

function file_size( i: integer ): real;
begin
  file_size := unsigned(dir.entries[i].filesize_hi) * 65536.0 +
               unsigned(dir.entries[i].filesize_lo)
end;

procedure increment_filesize( i, count: integer );
var
  j                : integer;
begin
  j := count;
  while j > 0 do
    begin
      j := pred(j);
      dir.entries[i].filesize_lo := succ(dir.entries[i].filesize_lo);
      if dir.entries[i].filesize_lo = 0
        then dir.entries[i].filesize_hi := succ(dir.entries[i].filesize_hi)
    end
end;

procedure transfer_setup( track, sector: Integer; var buffer: msdos_sector);
begin
  bpb.bc := msdos_disk_select;   { Select disk C: }
  bpb.de := selection_hint;
  bpb.fn := bios_seldsk;
  bdos(cpm_call_bios,addr(bpb));
  selection_hint := 1;
  bpb.bc := addr(buffer);        { Set DMA address }
  bpb.fn := bios_setdma;
  bdos(cpm_call_bios,addr(bpb));
  bpb.bc := track;               { Set track }
  bpb.fn := bios_settrk;
  bdos(cpm_call_bios,addr(bpb));
  bpb.bc := sector;              { Set sector }
  bpb.fn := bios_setsec;
  bdos(cpm_call_bios,addr(bpb));
end;

function write_sector( track, sector: Integer; buffer: msdos_sector): Integer;
begin
  transfer_setup( track, sector, buffer );
  bpb.fn := bios_write;
  write_sector := bdos(cpm_call_bios,addr(bpb));
  select_cpm_disk
end;

function read_sector( track, sector: Integer; var buffer: msdos_sector): Integer;
begin
  transfer_setup( track, sector, buffer );
  bpb.fn := bios_read;
  read_sector := bdos(cpm_call_bios,addr(bpb));
  select_cpm_disk
end;

