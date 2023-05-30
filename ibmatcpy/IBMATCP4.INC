procedure do_change_user_area;
var
  user             : integer;
begin
  write(' Enter CP/M user area number (0..15) : ');
  readln(user);
  if user in [0..15]
    then
      begin
        cpm_user := user;
        BDOS(cpm_setuser,user)
      end
end;

procedure do_copy_all_cpm_to_msdos;
var
  count            : integer;
  first            : FilePtr;
  cpmfilename      : str14;
  msdosfilename    : str12;
begin
  first := DirBase;
  directory_tree(first);
  count := 0;
  while first <> NIL do
    begin
      count := succ(count);
      if count = 1
        then writeln('Copying');
      cpmfilename := cpm_disk + ':' + first^.fname;
      first := first^.Next;
      msdosfilename := form_msdos_filename(copy(cpmfilename,3,12));
      cpmfilename := compress(cpmfilename);
      write('  ',msdosfilename);
      if lookup_file(msdosfilename) <> 0
        then writeln(' ? File already exists')
        else copy_cpm_file(cpmfilename,msdosfilename);
    end;
  if count > 0
    then write(count)
    else write('No');
  writeln(' files copied.')
end;

procedure do_cpm_directory;
const
  columns = 4;
var
  i, j, size, rows : integer;
  nodes            : array [1..columns] of FilePtr;
  this             : FilePtr;
  cpmfilename      : str14;
begin
  writeln('Directory of CP/M disk ',cpm_disk,cpm_user,':');
  writeln;
  this := DirBase;
  directory_tree(this);
  rows := DirEntries div columns;
  if 0 <> DirEntries mod columns
    then rows := succ(rows);
  nodes[1] := this;
  for i := 2 to columns do
    begin
      for j := 1 to rows do
        this := this^.next;
      nodes[i] := this
    end;
  i := 1;
  while i <= rows do
    begin
      for j := 1 to columns do
        begin
          this := nodes[j];
          if (i + rows*pred(j)) <= DirEntries
            then
              begin
                size := this^.fsize shr 3;
                if (this^.fsize mod 8) <> 0
                  then size := succ(size);
                write(this^.fname,' ',size:4,'k ');
                if j < columns
                  then write(' ')
                  else writeln
              end
            else writeln;
          nodes[j] := nodes[j]^.next
        end;
      i := succ(i)
    end;
  if j <> columns
    then writeln;
  if DirEntries = 0
    then writeln('No files.')
    else
      begin
        writeln;
        writeln('Total of ',DirEntries,' files, ',space_used,'k bytes.')
      end
end;

procedure do_copy_all_msdos_to_cpm;
var
  msdos_name       : Str12;
  cpm_name         : Str14;
  i, j, count      : integer;
begin
  count := 0;
  for i := 1 to dir_number_of_entries do
    begin
      if (not (dir.entries[i].filename[1] in
           [dir_unused,dir_E5,dir_directory,dir_erased])) and
         ((dir.entries[i].attribute and dir_VolumeLabel)=0)
        then
          begin
            msdos_name := '';
            for j := 1 to 8 do
              msdos_name := msdos_name + chr(dir.entries[i].filename[j]);
            msdos_name := msdos_name + '.';
            for j := 1 to 3 do
              msdos_name := msdos_name + chr(dir.entries[i].extension[j]);
            if (dir.entries[i].attribute and dir_SubDirectory) = 0
              then
                begin
                  count := succ(count);
                  msdos_name := compress(msdos_name);
                  cpm_name := cpm_disk + ':' + msdos_name;
                  if count = 1
                    then writeln('Copying');
                  writeln('  ',msdos_name);
                  copy_msdos_file(msdos_name, cpm_name)
                end
          end
    end;
  if count > 0
    then writeln(count,' files copied.')
end;

procedure do_copy_msdos_to_cpm;
var
  selection        : Str12;
  cpm_filename     : Str14;
begin
  write(' MS-DOS file to copy : ');
  readln(selection);
  selection := compress(selection);
  if length(selection) > 0
    then
      begin
        cpm_filename := cpm_disk + ':' + selection;
        copy_msdos_file(selection,cpm_filename)
      end
    else
      writeln('?Illegal MS-DOS filename.')
end;

procedure do_msdos_erase;
var
  selection        : Str12;
begin
  write(' MS-DOS file to erase : ');
  readln(selection);
  erase_msdos_file(selection)
end;

procedure do_copy_cpm_to_msdos;
var
  selection        : Str14;
  msdos_filename   : Str12;
  i                : integer;
begin
  write(' CP/M file to copy : ');
  readln(selection);
  i := pos(':',selection);
  msdos_filename := form_msdos_filename(copy(selection,succ(i),12));
  if i = 0
    then selection := cpm_disk + ':' + selection;
  if lookup_file(compress(msdos_filename)) <> 0
    then writeln('?MSDOS file already exists.')
    else
      copy_cpm_file(selection,msdos_filename)
end;

procedure do_select_cpm_drive;
var
  new_drive        : char;
begin
  write(' Enter CP/M drive name to use (A or B) <',cpm_disk,'> : ');
  readln(new_drive);
  new_drive := upcase(new_drive);
  if new_drive in ['A','B']
    then
      begin
        cpm_disk := new_drive;
        BDOS(cpm_resetdisk,0);
        BDOS(cpm_setuser,0);
        cpm_user := 0
      end
end;

procedure do_msdos_dir;
var
  i, j,
  number_of_files  : integer;
  filename, filsz  : str12;
  fs, used         : real;
begin
  used := 0.0;
  number_of_files := 0;
  writeln('Directory of disk ',volume_label:11,' (MSDOS Format)');
  writeln;
  for i := 1 to dir_number_of_entries do
    begin
      if not (dir.entries[i].filename[1] in
           [dir_unused,dir_E5,dir_directory,dir_erased])
        then
          begin
            filename := '';
            fs := file_size(i);
            for j := 1 to 8 do
              filename := filename + chr(dir.entries[i].filename[j]);
            if (dir.entries[i].attribute and dir_SubDirectory) = 0
              then
                begin
                  filename := filename + '.';
                  for j := 1 to 3 do
                    filename := filename + chr(dir.entries[i].extension[j]);
                  str(fs:8:0,filsz);
                  filsz := compress(filsz)
                end
              else
                begin
                  filename := filename + '    ';
                  filsz := '<DIR>'
                end;
            if (dir.entries[i].attribute and dir_VolumeLabel) = 0
              then
                begin
                  writeln( filename, ' ':8, filsz:8, ' ',
                           file_date(dir.entries[i].creation_date), ' ',
                           file_time(dir.entries[i].creation_time) );
                  used := used + fs;
                  number_of_files := succ(number_of_files)
                end
          end
    end;
  writeln;
  if number_of_files = 0
    then writeln('No files')
    else
      begin
        write('Total of ',number_of_files,' file');
        if number_of_files > 1
          then write('s');
        str(used:8:0,filsz);
        filsz := compress(filsz);
        writeln(' ',filsz,' bytes.')
      end
end;

procedure do_type_msdos_file;
var
  selection        : Str12;
begin
  write(' MS-DOS file to type : ');
  readln(selection);
  copy_msdos_file(selection,'CON:')
end;

