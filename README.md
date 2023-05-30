# BIGBOARD-II
CP/M Plus BIOS for Ferguson Bigboard-II

This repo contains a CP/M-Plus BIOS that I wrote for the Ferguson
BigBoard II single board computer in the 1980s.  You'll need a
copy of the CP/M-Plus distribution for the build utilities (RMAC,
LINK, GENCPM) and system file (BDOS3.SPR).

Included is a disassembly of the monitor ROM plus hard disk
utilities for a Shugart 1610-3 controller.  This can be built
using the Microsoft M80 macro assembler.

Time-of-day support is included using a Dallas semiconductor
DS1216 SmartWatch plugged into the U81 socket on the BigBoard II.

I've also included a Turbo Pascal program to transfer files
between CP/M disks and an IBM-PC/AT HD 5.25" MS-DOS format
floppy drive.  You'll need a copy of Turbo Pascal V3.01A for
CP/M-80 to build this.  The BIOS contains support for the
1.2MB 80-track 512 byte sector format.

Tony
