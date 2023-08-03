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

(*
 * Code from: https://github.com/Scalibq/DOS_SDK/blob/main/ASM/8259A.asm
 *)
procedure machine;
const MACHINE_PCXT: byte = 0;
      MACHINE_PCAT: byte = 1;
      MACHINE_PS2 : byte = 3;
      PC_PIC2_DATA : byte = $A1;   {compiler didn't allow this constants}
      PC_DELAY_PORT : byte = $EE;  {compiler didn't allow this constants}
var a : byte;
begin
    asm
        mov cl, MACHINE_PCXT
        push es

        {; Get BIOS configuration }
        mov ah, 0C0h
        int 015h
        jc @@notSupported

        mov al, es:[bx+5]    {; Get feature byte 1 }
        test al, 040h        {; Do we have a second 8259A? }
        jz @@exit

        mov cl, MACHINE_PCAT

        test al, 03h        {; Do we have MCA bus? }
        jz @@exit

        mov cl, MACHINE_PS2
        jmp @@exit
    
    @@notSupported:
        {; First try to test for known machine byte }
        mov ax, 0F000h
        mov es, ax
        mov al, es:[0FFFEh]
    
        {; Is it a PC, XT or PCjr (FF, FE and FD respectively) }
        cmp al, 0FDh
        jae @@exit
    
        {; Is it an AT? }
        cmp al, 0FCh
        jne @@unknownMachineType
    
        mov cl, MACHINE_PCAT
        jmp @@exit
    
    @@unknownMachineType:
        cli

        {; First check for physical second PIC }
        in al, $A1 {=PC_PIC2_DATA}
        mov bl, al    {; Save PIC2 mask }
        not al        {; Flip bits to see if they 'stick' }
        out $A1, al {=PC_PIC2_DATA}
        out $EE, al   {=PC_DELAY_PORT}  {; delay }
        in al, $A1 {=PC_PIC2_DATA}
        xor al, bl    {; If writing worked, we expect al to be 0FFh }
        inc al        {; Set zero flag on 0FFh }
        mov al, bl
        out $A1, al   {=PC_PIC2_DATA} {; Restore mask }
        jnz @@noCascade

        mov cl, MACHINE_PCAT
    
    @@noCascade:
        sti
    
    @@exit:
        pop es
        mov a, cl
    end;
    { Couldn't get this to work with Case-statement in combination with Const-values }
    if a = MACHINE_PCXT then writeln('PCXT')
    else 
        if a = MACHINE_PCAT then writeln('PCAT')
        else 
            if a = MACHINE_PS2 then writeln('PS2')
            else writeln('Unknown');
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
   textcolor(white); write('Machine: '); normvideo; machine;
   textcolor(white); write('Floating Point Unit: '); normvideo; fpu;

   writeln;
end.
