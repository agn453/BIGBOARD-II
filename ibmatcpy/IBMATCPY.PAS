program ibm_at_copy;

{
   IBMATCPY

   Program to copy files between CP/M-Plus and an IBM-PC/AT
   5.25" MS-DOS format high density floppy disk.

   This version is for a BigBoard-II with normal 8" CP/M
   drives on A: and B:, and the 5.25" drive on C: and
   requires the BIOS floppy disk module that recognises
   the 512 byte/9 sectors per track/80 track format.

   Author:  Tony Nicholson
}

const
  version          =  '1.1  23-Apr-87';
  debug            = TRUE;

{$I IBMATCPY.DEF }

var
  sector_buffer    : msdos_sector;
  bpb              : bios_parameter_block;
  dir              : directory;
  fat              : file_allocation_table;
  DirBase          : FilePtr;
  volume_label     : Str12;
  cpm_user,
  DirEntries,
  selection_hint,
  space_used       : integer;
  done             : boolean;
  command,
  cpm_disk         : char;

{$I IBMATCP1.INC }
{$I IBMATCP2.INC }
{$I IBMATCP3.INC }
{$I IBMATCP4.INC }

procedure do_help;
begin
  writeln('Available commands are -');
  writeln;
  writeln(' A --> Copy all MS-DOS files to CP/M disk');
  writeln(' C --> Copy file to CP/M disk');
  writeln(' D --> Directory of MS-DOS disk');
  writeln(' E --> Erase MS-DOS file');
  writeln(' F --> CP/M File directory');
  writeln(' M --> Copy file to MS-DOS disk');
  writeln(' N --> Restart with new disk(s)');
  writeln(' P --> Put all CP/M files to MS-DOS disk');
  writeln(' Q --> Quit program');
  writeln(' S --> Select CP/M drive');
  writeln(' T --> Type MS-DOS file on console')
end;

begin { ibm_at_copy }
  ClrScr;
  LowVideo;
  writeln('IBM-PC/AT 1.2 Mbyte MS-DOS <--> CP/M Disk Copy Program V',version);
  writeln('[For CP/M-Plus on Bigboard II with 5-1/4" 80 track AT disk drive]');
  writeln;
  if cpm_version_ok
    then
      begin
        DirBase := NIL;
        DirEntries := 0;
        space_used := 0;
        cpm_disk := 'A';
        if not change_disks
          then halt;
        done := FALSE;
        while not done do
        begin
          writeln;
          write('Command: ');
          readln(command);
          writeln;
          command := upcase(command);
          case command of
            'A': { Copy all files to CP/M disk }
                 do_copy_all_msdos_to_cpm;
            'C': { Copy to CP/M disk }
                 do_copy_msdos_to_cpm;
            'D': { Directory of MS-DOS disk }
                 do_msdos_dir;
            'E': { Erase MS-DOS file }
                 do_msdos_erase;
            'F': { CP/M directory }
                 do_cpm_directory;
            'H',
            '?': { Help }
                 do_help;
            'M': { Copy to MS-DOS disk }
                 do_copy_cpm_to_msdos;
            'N': { New disks }
                 if change_disks
                   then writeln('New disk(s) selected');
            'P': { Put all files to MS-DOS disk }
                 do_copy_all_cpm_to_msdos;
            'Q': { Quit }
                 done := TRUE;
            'S': { Select CP/M drive }
                 do_select_cpm_drive;
            'T': { Type MS-DOS file }
                 do_type_msdos_file;
            'U': { change CP/M user area }
                 do_change_user_area;
            else
              writeln('Type ? for HELP');
          end
        end;
      writeln('Put CP/M system disk in drive A:');
      while not press_CR do;
      BDOS(cpm_resetdisk,0)
    end
  else
    writeln('Sorry, this program requires CP/M Plus')
end.
