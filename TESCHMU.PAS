{$define work }
{$undef work }     { raus für arbeiten (work) }

{$ifndef work }
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-}
{$endif }

{$M 5096,0,0}

uses dos,crt;

Type feldtyp   = array[0..12,0..19] of byte;
     mfeldtyp  = array[0..3,0..3] of byte;
     screentyp = array[0..1999] of byte;

Const form  : array[0..6,0..3,0..1] of byte =
                (((1,1),(1,1),(0,0),(0,0)),   { **
                                                **   }

                 ((1,0),(1,1),(0,1),(0,0)),   { **
                                                 **  }

                 ((1,0),(1,0),(1,0),(1,0)),   { **** }

                 ((1,0),(1,0),(1,1),(0,0)),   { ***
                                                  *  }

                 ((1,1),(1,0),(1,0),(0,0)),   { ***
                                                *    }

                 ((0,1),(1,1),(1,0),(0,0)),   {  **
                                                **   }

                 ((1,0),(1,1),(1,0),(0,0)));  { ***
                                                 *   }

var merkx,
    merky      : byte;
    reg        : registers;
    i, j       : integer;
    alt8       : pointer;
    screen     : screentyp absolute $b800:0000;
    screenc    : screentyp;
    feld,
    wfeld      : feldtyp;
    sfeld,
    mfeld      : mfeldtyp;
    xpos,
    ypos,
    kont       : byte;
    found      : boolean;
    best       : array[0..9,0..2] of integer;
    aktiv      : boolean;

procedure display( VAR was : feldtyp);
Var i, j : integer;
begin
  for j:=0 to 19 do begin
    gotoxy(30,j+2);
    for i:=0 to 9 do
      case was[i,j] of
        0 : write(' ');
        1 : write('█');
        2 : write('K');
        3 : write('X');
      end;
  end;
end;

procedure konturcopy(VAR mfeld : mfeldtyp; kontur : byte);
Var i, j : Integer;
begin
  fillchar(mfeld,sizeof(mfeld),#0);
  for i:=0 to 3 do
    for j:=0 to 1 do
      mfeld[i,j]:=form[kontur,i,j];
end;

procedure konturdreh(VAR mfeld : mfeldtyp);  { FORTRAN KLAUSUR 14/02/89 }
Var i,j : Integer;
    p   : Byte;
begin
  for i:=0 to 3 do
    for j:=0 to i do begin
      p:=mfeld[i,j];
      mfeld[i,j]:=mfeld[j,i];
      mfeld[j,i]:=p;
    end;
  for i:=0 to 3 do
    for j:=0 to 1 do begin
      p:=mfeld[i,j];
      mfeld[i,j]:=mfeld[i,3-j];
      mfeld[i,3-j]:=p;
    end;                                     { ende FORTRAN }

  { jetzt noch ganz nach links verschieben }
  while (mfeld[0,0]=0) and (mfeld[0,1]=0) and
        (mfeld[0,2]=0) and (mfeld[0,3]=0) do begin
     for i:=1 to 3 do
       for j:=0 to 3 do
         mfeld[i-1,j]:=mfeld[i,j];
     for j:=0 to 3 do
       mfeld[3,j]:=0;
  end;

  { und jetzt ganz nach unten verschieben }
  while (mfeld[0,3]=0) and (mfeld[1,3]=0) and
        (mfeld[2,3]=0) and (mfeld[3,3]=0) do begin
    for i:=0 to 3 do
      for j:=2 downto 0 do
        mfeld[i,j+1]:=mfeld[i,j];
    for i:=0 to 3 do
      mfeld[i,0]:=0;
  end;
end;

procedure konturhoch(VAR mfeld : mfeldtyp);
Var i : Integer;
begin
  while (mfeld[0,0]=0) and (mfeld[1,0]=0) and
        (mfeld[2,0]=0) and (mfeld[3,0]=0) do begin
    for i:=0 to 3 do
      for j:=1 to 3 do
        mfeld[i,j-1]:=mfeld[i,j];
    for i:=0 to 3 do
      mfeld[i,3]:=0;
  end;
end;

procedure findkontur;
Var i, j,
    k, l  : Integer;
    count : byte;
    loop  : byte;

begin
  found:=false;
  wfeld:=feld;

  j:=0;
  repeat

    gotoxy(29,j+2);   write('╫');
    gotoxy(40,j+2);   write('╫');

    i:=0;
    repeat

      kont:=0;
      repeat

        konturcopy(mfeld,kont);
        konturhoch(mfeld);

        loop:=0;
        repeat

          count:=0;
          for k:=0 to 3 do
            for l:=0 to 3 do
              if mfeld[k,l]=feld[i+k,j+l]
                then inc(count);
          if count=16
            then found:=true
            else begin
              konturdreh(mfeld);
              inc(loop);
            end;

        until (loop=4) or found;

        if not found then
          inc(kont);
      until (kont>6) or found;

      if not found then
        inc(i);
    until (i>9) or found;

    gotoxy(29,j+2);   write('║');
    gotoxy(40,j+2);   write('║');

    if not found then
      inc(j);



  until (found) or (j>15);

  if found then begin
    for k:=0 to 3 do
      for l:=0 to 3 do begin
        inc(wfeld[i+k,j+l],mfeld[k,l]);
        dec(feld[i+k,j+l],mfeld[k,l]);
      end;
    xpos:=i;
    ypos:=j;
  end;
end;
{ damit enthält mfeld die derzeitige lage der gefundendn kontur,
  xpos, ypos die ecke,
  kont die konturnummer
  und found ist true wenn gefunden }

procedure findfitt;
Var i, j,
    k, l,
    m     : Integer;
    temp  : feldtyp;
    ok    : Boolean;
    fine  : byte;
    count : byte;


  function calpkte(VAR feld : feldtyp):Integer;
  Var i, j : Integer;
      t    : integer;
  begin
    t:=0;

(*
    for i:=0 to 9 do                  { punkte für jedes feld }
      for j:=1 to 19 do
        if feld[i,j]<>0
          then inc(t,j*3);

    for i:=0 to 9 do                  { zwei übereinander }
      for j:=1 to 18 do
        if (feld[i,j]<>0) and (feld[i,j+1]<>0)
          then inc(t);
*)
    for i:=0 to 9 do                  { punkte für jedes feld }
      for j:=1 to 19 do
        if feld[i,j]<>0
          then inc(t,j*12);

    for i:=0 to 9 do                  { zwei übereinander }
      for j:=1 to 18 do
        if (feld[i,j]<>0) and (feld[i,j+1]<>0)
          then inc(t,j*3);

    for i:=0 to 9 do                  { zwei übereinander }
      for j:=1 to 17 do
        if (feld[i,j]<>0) and (feld[i,j+1]<>0) and (feld[i,j+2]<>0)
          then inc(t);

    for j:=19 downto ypos do
      if (feld[0,j]<>0) and (feld[1,j]<>0) and (feld[2,j]<>0) and
         (feld[3,j]<>0) and (feld[4,j]<>0) and (feld[5,j]<>0) and
         (feld[6,j]<>0) and (feld[7,j]<>0) and (feld[8,j]<>0) and
         (feld[9,j]<>0)
        then inc(t,j*146);
    calpkte:=t;
  end;

  procedure addtobest;
  Var max, ii : Integer;
  begin
    max:=calpkte(temp);
    ii:=0;
    while (best[ii,0]>=max) and (ii<9) do
      inc(ii);
    best[ii,0]:=max;
    best[ii,1]:=i-xpos;
    best[ii,2]:=count;
  end;


begin
  display(feld);
  temp:=feld;
  sfeld:=mfeld;

  j:=16;

  repeat

    i:=0;
    fine:=0;


    repeat;
      count:=0;
      repeat
        ok:=true;
        temp:=feld;
        for k:=0 to 3 do
          for l:=0 to 3 do
            inc(temp[i+k,j+l],2*sfeld[k,l]);

        for k:=i to i+3 do
          for l:=j to j+3 do
            if temp[k,l]>2 then
              ok:=false;
        if ok then
          for k:=i to i+3 do begin
            l:=0;
            while (sfeld[k-i,l]=0) and (l<3) do
              inc(l);
            if (l<3) or (sfeld[k-i,3]=1) then
              for m:=j+l-1 downto 0 do
                if temp[k,m]<>0 then
                  ok:=false;
          end;
        if ok then begin
          addtobest;
          ok:=false;
          inc(fine);
          display(temp);
        end;
        konturdreh(sfeld);
        inc(count);

    until (count>=4);
    inc(i);
    until (i>9);
    dec(j);
  until (j<ypos) or (fine>=34);
end;

procedure getfeld;
Var i, j : Integer;
begin
  fillchar(feld,sizeof(feld),#1);

  for i:=0 to 9 do
    for j:=0 to 19 do
      if screen[i*2+111+j*80]<>1
        then feld[i,j]:=1
        else feld[i,j]:=0;
end;

procedure putchar(c:char);
Var bufferhead : Integer absolute $40:$1a;
    buffertail : Integer absolute $40:$1c;
begin
{$ifndef work }
  inline($fa);
  memw[$40:buffertail]:=ord(c);
  inc(buffertail,2);
  if buffertail>=$3e then
    buffertail:=$1e;
  inline($fb);
{$endif }
end;

procedure machbest;
Var i          : integer;
    move, turn : Integer;
begin
  while keypressed do
    i:=ord(readkey);

{
  for i:=0 to 9 do begin
    gotoxy(1,10+i);
    write(best[i,0]:5,best[i,1]:3,best[i,2]:3);
  end;
  i:=ord(readkey);
}


  move:=best[0,1];
  turn:=best[0,2];
  if odd(turn) then
    if kont=2 then dec(move,2)
              else dec(move);
  if (kont=3) and (turn=3) then
    inc(move);
  if (kont in [4,6]) and (turn=3) then
    inc(move);

  for i:=1 to turn do
    putchar('8');

  if move>0 then
    for i:=1 to move do
      putchar('9');
  if move<0 then
    for i:=1 to -move do
      putchar('7');

  putchar(' ');
end;

procedure do_it; {$ifndef work } Interrupt; {$endif }
begin
  if not aktiv then begin
    aktiv:=true;
    merkx:=wherex;
    merky:=wherey;
    screenc:=screen;

    gotoxy(1,6);  write('╔══════════╗');
    gotoxy(1,7);  write('║TETRIS    ║');
    gotoxy(1,8);  write('║    spielt║');
    gotoxy(1,9);  write('╚══════════╝');
    for i:=2 to 22 do begin
      gotoxy(29,i); write('║');
      gotoxy(40,i); write('║');
    end;
    gotoxy(29,22);
    write('╚══════════╝');

    getfeld;

    fillchar(best,sizeof(best),#0);

    display(feld);

    findkontur;

    if found then begin
      findfitt;
      machbest;
    end;

    display(wfeld);

    screen:=screenc;

    gotoxy(merkx,merky);
    aktiv:=false;
  end;
end;

{$ifdef work }
procedure machpseudo;
Var i, j : Integer;
begin
  textmode(co40);
  textcolor(1);
  clrscr;

  for i:=1 to 21 do begin
    gotoxy(15,i); write('*');
    gotoxy(26,i); write('*');
  end;
  for i:=15 to 26 do begin
    gotoxy(i,22); write('*');
  end;


  textcolor(red);

  gotoxy(17,5); write('█');
  gotoxy(17,4); write('███');


  randomize;
  for i:=1 to 28 do begin
    gotoxy(16+random(10),15+random(7));
    write('█');
  end;

end;
{$endif }



begin
  aktiv:=false;

  writeln('╔══════════════════╗');
  writeln('║Laß TETRIS spielen║');
  writeln('╚══════════════════╝');

{$ifdef work }
  machpseudo;
  do_it;

{$else }
  SetIntVec($5,@do_it);

  swapvectors;             { !!!! }
  keep(0);
{$endif}

end.
