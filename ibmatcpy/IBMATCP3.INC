procedure copy_msdos_file( msdos_file: Str12; to_cpm_file: Str14 );
var
  i, j, found,
  trk, sec, clust  : integer;
  selection        : str12;
  fs               : real;
  cpm_file         : text;
begin
  assign(cpm_file,to_cpm_file);
  {$I-} rewrite(cpm_file) {$I+};
  if IOresult = 0
    then
      begin
        selection := compress(uppercase(msdos_file));
        found := lookup_file(selection);
        if found = 0
          then
            begin
              close(cpm_file);
              {$I-} erase(cpm_file) {$I+};
              writeln('?CP/M File not found')
            end
          else
            begin
              fs := file_size(found);
              clust := dir.entries[found].start_cluster;
              while fs > 0.0 do
                begin
                  cluster_to_trk_sec( clust, trk, sec );
                  j := sector_size;
                  if fs < j
                    then j := trunc(fs);
                  if read_sector( trk, sec, sector_buffer )=0
                    then
                      for i := 1 to j do
                        write(cpm_file,chr(sector_buffer[i]));
                  fs := fs - j;
                  clust := next_cluster(clust);
                  if (clust >= $FF8) and (clust <= $FFF) and (fs > 0.0)
                    then
                      begin
                        writeln;
                        writeln('?Premature EOF with ',fs:8:0,' bytes remaining.');
                        fs := 0
                      end
                end;
              close(cpm_file)
            end
      end
    else
      writeln('?Cannot create CP/M file ',to_cpm_file)
end;

procedure copy_cpm_file( cpm_filename: Str14; to_msdos_file: Str12 );
var
  i, j, found,
  trk, sec, clust,
  status           : integer;
  dd, mm, yy,
  hr, mn, sc       : byte;
  c                : char;
  fs               : real;
  fsz              : string[8];
  cpm_file         : file;
begin
  DateTime( dd, mm, yy, hr, mn, sc );
  assign(cpm_file,cpm_filename);
  {$I-} reset(cpm_file) {$I+};
  if IOresult = 0
    then
      begin
        clust := next_free_cluster(1);
        found := free_directory_entry;
        if (clust <> 0) and (found<>0)
          then
            begin
              fs := 0.0;
              with dir.entries[found] do
                begin
                  for i := 1 to 8 do
                    filename[i] := ord(to_msdos_file[i]);
                  for i := 1 to 3 do
                    extension[i] := ord(to_msdos_file[i+9]);
                  attribute := 0;
                  for i := 1 to 10 do
                    reserved[i] := 0;
                  creation_date := date_file(dd,mm,yy);
                  creation_time := time_file(hr,mn,sc);
                  start_cluster := clust;
                  filesize_lo := 0;
                  filesize_hi := 0
                end;
              j := 1;
              cluster_to_trk_sec( clust, trk, sec );
              while not eof(cpm_file) do
                begin
                  if j > sector_size
                    then
                      begin
                        status := write_sector( trk, sec, sector_buffer );
                        fs := fs + sector_size;
                        increment_filesize(found, sector_size);
                        clust := next_free_cluster( clust );
                        cluster_to_trk_sec( clust, trk, sec );
                        j := 1
                      end;
                  blockread(cpm_file, sector_buffer[j], 1);
                  j := j + 128;
                end;
              close(cpm_file);
              if j > 1
                then
                  begin
                    for i := j to sector_size do
                      sector_buffer[i] := 0;
                    status := write_sector( trk, sec, sector_buffer )
                  end;
              fs := fs + pred(j);
              increment_filesize(found, pred(j));
              update_FAT( clust, $FFF );
              if not write_msdos_fat
                then writeln('?Error writing FAT, disk is possibly unusable');
              if not write_msdos_dir
                then writeln('?Error updating directory, disk is possibly unusable');
              str(fs:8:0,fsz);
              writeln;
              writeln(' File copied (',compress(fsz),' bytes)')
            end
      end
    else
      writeln('?Cannot find CP/M file ',cpm_filename)
end;

procedure erase_msdos_file( msdos_file: Str12 );
var
  selection        : Str12;
  found            : integer;
begin
  selection := compress(uppercase(msdos_file));
  found := lookup_file(selection);
  if found = 0
    then writeln('?MS-DOS File not found')
    else
      begin
        dir.entries[found].filename[1] := dir_erased;
        if not write_msdos_dir
          then writeln('?Error updating directory, disk is possibly unusable')
      end
end;

procedure Insert_tree(fn: Str12; size: integer;
                      var entries, total: integer; var first: FilePtr);
var
  this, last, f    : FilePtr;
  space            : integer;
begin
  last := NIL;
  this := first;
  while (this <> NIL) and (this^.fname < fn) do
    begin
      last := this;
      this := this^.next
    end;
  space := size shr 3;
  if (size mod 8) <> 0
    then space := succ(space);
  if this^.fname <> fn
    then
      begin
        total := total + space;
        entries := succ(entries);
        new(f);
        f^.fname := fn;
        f^.fsize := size;
        f^.next := this;
        if last = NIL
          then first := f
          else last^.next := f
      end
    else if (this^.fname = fn) and (this^.fsize < size)
      then
        begin
          total := total + space;
          space := this^.fsize shr 3;
          if (this^.fsize mod 8) <> 0
            then space := succ(space);
          total := total - space;
          this^.fsize := size
        end
end;

procedure directory_tree(var first: FilePtr);
var
  i, off           : integer;
  this             : FilePtr;
  searchblk        : FileBlock;
  answerblk        : array [0..3] of FileBlock;
  fn               : str12;

begin
  space_used := 0;
  DirEntries := 0;
  while first <> NIL do
    begin
      this := first;
      first := first^.Next;
      dispose(this)
    end;
  with searchblk do
    begin
      drive := ord(cpm_disk)-ord('@');
      for i := 1 to 11 do
        fname[i] := ord('?');
      extent := ord('?');
      s1 := ord('?');
      s2 := ord('?');
      reccount := 0;
      for i := 16 to 31 do
        map[i] := 0
    end;
  BDOS(cpm_setdma, addr(answerblk));
  off := BDOS(cpm_findfirst, addr(searchblk));
  while off <> 255 do
    begin
      with answerblk[off] do
        begin
          fn := 'xxxxxxxx.xxx';
          for i := 1 to 8 do
            fn[i] := chr(fname[i] and $7F);
          for i := 9 to 11 do
            fn[i+1] := chr(fname[i] and $7F);
          Insert_tree(fn, reccount+(extent+(s2 shl 5)) shl 7,
                      DirEntries, space_used, first)
        end;
      off := BDOS(cpm_findnext, addr(searchblk))
    end;
  DirBase := first;
  BDOS(cpm_setdma,cpm_FCB)
end;

