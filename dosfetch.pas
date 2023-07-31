(* dosfetch - a neofetch clone for DOS
 *
 * Written by Leah Neukirchen <leah@vuxu.org>
 *
 * To the extent possible under law, the creator of this work has waived
 * all copyright and related or neighboring rights to this work.
 *)

program dosfetch;

uses crt, dos;

{
More ideas:
- uptime (hard)
- CPU details
}

function cmos(cmd: byte): byte;
begin
   port[$70] := cmd;
   cmos := port[$71];
end;

procedure base_memory;
var a : integer;
begin
   asm
     int $12;
     mov a, ax;
   end;
   writeln(a, ' KB');
end;

procedure extended_memory;
var a, c, d : integer;
    l : longint;
    err : byte;
begin
   err := 0;

   asm
     mov ah, $88;
     int $15;
     jnc @@skip;
     mov err, ah;
     @@skip:
     mov a, ax;
   end;

   if err > 0 then
      writeln('none')  { XXX could be wrong on XT }
   else begin
      asm
         clc;
         mov ax, $E801;
         int $15;
         jnc @@skip;
         mov err, ah;
         @@skip:
         mov c, cx;
         mov d, dx;
      end;

      if err > 0 then
         writeln(cmos($17) + 256*longint(cmos($18)), ' KB')
      else
         writeln(longint(c) + 64*longint(d), ' KB');
   end;
end;

procedure disksize(disk: byte);
var a, b, c, d : word;
   total, free : longint;
begin
   asm
     mov ah, $36;
     mov dl, disk;
     int $21;
     mov a, ax;
     mov b, bx;
     mov c, cx;
     mov d, dx;
   end;
   free := longint(a)*longint(c)*longint(b);
   total := longint(a)*longint(c)*longint(d);
   write(total div 1024 - free div 1024, '/', total div 1024, ' KB (');
   writeln(round((free/total)*100), '% free)');
end;

procedure dosver;
var maj, min, ven : byte;
    smaj, smin, sven :  string;
begin
   asm
     mov ax, $3000;
     int $21;
     mov ven, bh;
     mov ax, $3306;
     int $21;
     mov maj, bl;
     mov min, bh;
   end;

  case ven of
    $00 : write('IBM DOS ');
    $FD : write('FreeDOS ');
    $FF : write('MS DOS ');
    else write('Unknown DOS ');
  end;
  writeln(maj, '.', min);
end;

procedure floppy;
var a : byte; f : integer;
begin
   asm
     int $11;
     mov a, al;
  end;
  if ((a and $1) = $1) then
     f := (a shr 6) + 1
  else
     f := 0;
  writeln(f);
end;

procedure fpu;
var a : byte;
begin
   asm
     int $11;
     mov a, al;
  end;
  if ((a and $2) = $2) then
     writeln('YES')
  else
     writeln('no');
end;


procedure colorline(s : string);
var y, b, r : string;
begin
   textcolor(yellow);     write(copy(s, 1, 14));
   textcolor(lightblue);  write(copy(s, 15,14));
   textcolor(lightred);   write(copy(s, 29,14));
   normvideo;
   writeln;
end;

begin
   clrscr;
   writeln;

   window(2, 2, 80, 25);
   colorline('88888888ba,     ,ad8888ba,    ad88888ba  ');
   colorline('88      `"8b   d8"''    `"8b  d8"     "8b ');
   colorline('88        `8b d8''        `8b Y8,         ');
   colorline('88         88 88          88 `Y8aaaaa,   ');
   colorline('88         88 88          88   `"""""8b, ');
   colorline('88         8P Y8,        ,8P         `8b ');
   colorline('88      .a8P   Y8a.    .a8P  Y8a     a8P ');
   colorline('88888888Y"''     `"Y8888Y"''    "Y88888P"');

   window(45, 2, 80, 25);
   textcolor(white); write('OS: '); normvideo; dosver;
   textcolor(white); write('Shell: '); normvideo; writeln(getenv('COMSPEC'));
   textcolor(white); write('Floppy drives: '); normvideo; floppy;
   textcolor(white); write('Disk: '); normvideo; disksize(0);
   textcolor(white); write('Base Memory: '); normvideo; base_memory;
   textcolor(white); write('Ext. Memory: '); normvideo; extended_memory;
   textcolor(white); write('Floating Point Unit: '); normvideo; fpu;

   writeln;
end.
