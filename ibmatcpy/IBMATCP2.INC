procedure cluster_to_trk_sec( clust: Integer; var trk, sec: integer);
var
  log_sec          : integer;
begin
  log_sec := (clust - 2) * cluster_size + data_area_start;
  sec := log_sec mod sectors_per_track;
  trk := log_sec div sectors_per_track;
end;

function next_cluster( last_cluster: integer ): integer;
var
  fat_ofs,
  new_cluster      : integer;
begin
  fat_ofs := succ(trunc( 1.5 * last_cluster ));
  new_cluster := (FAT.bytes[fat_ofs] and $FF) or
                 ((FAT.bytes[succ(fat_ofs)] and $FF) shl 8);
  if (last_cluster mod 2) = 0
    then new_cluster := (new_cluster and $FFF)
    else new_cluster := ((new_cluster shr 4) and $FFF);
  next_cluster := new_cluster
end;

procedure update_FAT( entry, clust: integer );
var
  fat_ofs          : integer;
begin
  fat_ofs := succ(trunc( 1.5 * entry ));
  if (entry mod 2) = 0
    then
      begin
        FAT.bytes[fat_ofs] := clust and $FF;
        fat_ofs := succ(fat_ofs);
        FAT.bytes[fat_ofs] := (FAT.bytes[fat_ofs] and $F0) or
                              ( (clust shr 8) and $0F )
      end
    else
      begin
        clust := (clust shl 4) and $FFF0;
        FAT.bytes[fat_ofs] := (FAT.bytes[fat_ofs] and $0F) or
                              ( clust and $F0 );
        fat_ofs := succ(fat_ofs);
        FAT.bytes[fat_ofs] := ( clust shr 8) and $FF
      end;
end;

function next_free_cluster( last_cluster: integer ): integer;
var
  clust, fat_ofs,
  new_cluster      : integer;
begin
  clust := last_cluster;
  repeat
    clust := succ(clust);
    fat_ofs := succ(trunc( 1.5 * clust ));
    new_cluster := (FAT.bytes[fat_ofs] and $FF) or
             ((FAT.bytes[succ(fat_ofs)] and $FF) shl 8);
    if (clust mod 2) = 0
      then new_cluster := (new_cluster and $FFF)
      else new_cluster := ((new_cluster shr 4) and $FFF)
  until (new_cluster = 0) or (clust >= $960);
  if clust >= $960
    then
      begin
        writeln('?MS-DOS disk full - no more clusters');
        clust := 0
      end
    else if last_cluster > 1
      then update_FAT( last_cluster, clust );
  next_free_cluster := clust
end;

procedure release_clusters( i: integer );
var
  clust, chain     : integer;
begin
  chain := dir.entries[i].start_cluster;
  repeat
    clust := next_cluster( chain );
    update_FAT( chain, 0 );
    chain := clust;
  until clust in [$FF8..$FFF]
end;

function read_msdos_dir: boolean;
var
  i, j,
  trk, sec, status : Integer;
  found_label      : boolean;
begin
  trk := dir_track;
  sec := dir_start;
  repeat
    status := read_sector( trk, sec, dir.sectors[sec] );
    sec := succ(sec)
  until (sec>dir_end) or (status<>0);
  volume_label := '';
  i := 1;
  found_label := FALSE;
  while (not found_label) and (i <= dir_number_of_entries) do
    begin
      found_label := ((dir.entries[i].attribute and dir_VolumeLabel)<>0);
      if found_label
        then
          begin
            for j := 1 to 8 do
              volume_label := volume_label + chr(dir.entries[i].filename[j]);
            for j := 1 to 3 do
              volume_label := volume_label + chr(dir.entries[i].extension[j])
          end
        else i := succ(i)
    end;
  read_msdos_dir := (status = 0)
end;

function write_msdos_dir: boolean;
var
  trk, sec, status : Integer;
begin
  trk := dir_track;
  sec := dir_start;
  repeat
    status := write_sector( trk, sec, dir.sectors[sec] );
    sec := succ(sec)
  until (sec>dir_end) or (status<>0);
  write_msdos_dir := (status = 0)
end;

function read_msdos_fat: boolean;
var
  trk, sec, status : Integer;
begin
  trk := reserved_track;
  sec := fat1_start;
  repeat
    status := read_sector( trk, sec, fat.sectors[sec] );
    sec := succ(sec)
  until (sec>fat1_end) or (status<>0);
  read_msdos_fat := (status = 0) and (fat.bytes[1] = media_type)
end;

function write_msdos_fat: boolean;
var
  trk, sec, status : Integer;
begin
  trk := reserved_track;
  sec := fat1_start;
  repeat
    status := write_sector( trk, sec, fat.sectors[sec] );
    sec := succ(sec)
  until (sec>fat1_end) or (status<>0);
  write_msdos_fat := (status = 0)
end;

function change_disks: boolean;
var
  dir_read,
  fat_read         : boolean;
begin
  writeln('Put CP/M 8" floppy disk into drive ',cpm_disk,':');
  writeln(' & MS-DOS 5-1/4" floppy into drive C:');
  if press_CR
    then
      begin
        BDOS(cpm_resetdisk,0);
        BDOS(cpm_seldsk,ord(cpm_disk)-ord('A'));
        BDOS(cpm_setuser,0);
        cpm_user := 0;
        selection_hint := 0;
        dir_read := read_msdos_dir;
        fat_read := read_msdos_fat;
        change_disks := (dir_read and fat_read)
      end
    else
      change_disks := FALSE
end;

function free_directory_entry: integer;
var
  i                : integer;
  found            : boolean;
begin
  found := FALSE;
  i := 0;
  repeat
    i := succ(i);
    if dir.entries[i].filename[1] = dir_unused
      then found := TRUE
  until found or (i=dir_number_of_entries);
  if not found
    then
      begin { look for deleted files }
        i := 0;
        repeat
          i := succ(i);
          if dir.entries[i].filename[1] = dir_erased
            then
              begin
                release_clusters(i);
                found := TRUE
              end
        until found or (i=dir_number_of_entries);
      end;
  if found
    then free_directory_entry := i
    else free_directory_entry := 0
end;

function lookup_file( selection: Str12 ): Integer;
var
  i, j             : integer;
  filename         : Str12;
  found            : boolean;
begin
  i := 0;
  found := FALSE;
  repeat
    i := succ(i);
    filename := '';
    if not (dir.entries[i].filename[1] in
         [dir_unused,dir_E5,dir_directory,dir_erased])
      then
        begin
          for j := 1 to 8 do
            filename := filename + chr(dir.entries[i].filename[j]);
          filename := filename + '.';
          for j := 1 to 3 do
            filename := filename + chr(dir.entries[i].extension[j]);
        end;
    found := (compress(filename) = selection)
  until found or (i=dir_number_of_entries);
  if found
    then lookup_file := i
    else lookup_file := 0
end;

function form_msdos_filename( msdos_filename : Str12 ): Str12;
var
  i                : integer;
begin
  msdos_filename := uppercase(compress( msdos_filename ));
  i := pos('.',msdos_filename);
  if i = 0
    then form_msdos_filename := pad(copy(msdos_filename,1,8),8) + '.   '
    else form_msdos_filename := pad(copy(msdos_filename,1,pred(i)),8) +
                           pad(copy(msdos_filename,i,4),4)
end;

