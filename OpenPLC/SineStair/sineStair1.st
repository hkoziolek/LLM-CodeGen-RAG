FUNCTION FLOOR2 : DINT
  VAR_INPUT
    x : REAL;
  END_VAR

  FLOOR2 := REAL_TO_DINT(X);
  IF DINT_TO_REAL(FLOOR2) > X THEN
  	FLOOR2 := FLOOR2 - DINT#1;
  END_IF;
  (* from OSCAT library; www.oscat.de  *)
END_FUNCTION

FUNCTION MODR : REAL
  VAR_INPUT
    IN : REAL;
    DIVI : REAL;
  END_VAR

  IF divi = 0.0 THEN
  	MODR := 0.0;
  ELSE
  	MODR := in - DINT_TO_REAL(FLOOR2(in / divi)) * divi;
  END_IF;
  (* from OSCAT library; www.oscat.de  *)
  (* FC FLOOR2 required *)
END_FUNCTION

FUNCTION SIGN_R : BOOL
  VAR_INPUT
    IN : REAL;
  END_VAR

  SIGN_R := in < 0.0;
  (* from OSCAT library; www.oscat.de  *)
END_FUNCTION

FUNCTION T_PLC_MS : UDINT
  VAR
    tx : UDINT;
  END_VAR
  VAR_INPUT
    debug : BOOL;
  END_VAR
  VAR
    N : INT := 0;
    offset : UDINT := 0;
    temp : DWORD := 1;
  END_VAR

  tx := 0;

  {extern unsigned long __tick;
  extern unsigned long long common_ticktime__;
  unsigned long long ticktime_ms = (common_ticktime__)/1000000;
  UDINT plc_time = (UDINT)(ticktime_ms * (unsigned long long)__tick);
  TX = plc_time}

  T_PLC_MS := tx;
  IF debug THEN
  	T_PLC_MS := (DWORD_TO_UDINT(SHL(UDINT_TO_DWORD(T_PLC_MS),N) OR SHL(temp,N))-1) + OFFSET;
  END_IF;

  (* Original Code:
  tx := TIME();
  T_PLC_MS := TIME_TO_DWORD(Tx);
  IF debug THEN
  	T_PLC_MS := (SHL(T_PLC_MS,N) OR SHL(DWORD#1,N)-1) + _OFFSET;
  END_IF;
  *)

  (* From OSCAT library, www.oscat.de

  this is a temporary T_PLC_MS FB until OpenPLC gets it´s own time() functionality *)

  (* PLC_TIME and Global variables PLC_SCAN_CYCL and PLC_CYCL_TIME required *)
END_FUNCTION

FUNCTION_BLOCK GEN_SIN
  VAR_INPUT
    PT : TIME;
    AM : REAL := 1.0;
    OS : REAL;
    DL : REAL;
  END_VAR
  VAR_OUTPUT
    Q : BOOL;
    OUT : REAL;
  END_VAR
  VAR
    tx : TIME;
    last : TIME;
    init : BOOL;
    temp : REAL;
  END_VAR

  tx:= UDINT_TO_TIME(T_PLC_MS(en:=true)) - last;

  DL := modR(dl,1.0);
  IF dl < 0.0 THEN dl := 1.0 - dl; END_IF;

  (* init section *)
  IF NOT init THEN
  	init := TRUE;
  	last := tx;
  	tx := t#0s;
  END_IF;

  (* add last if one cycle is finished *)
  IF tx >= pt THEN
  	last := last + pt;
  	tx := tx - pt;
  END_IF;

  (* generate sine wave *)
  IF pt > t#0s THEN temp := SIN(6.283185307179586476 * TIME_TO_REAL(tx + multime(pt, dl)) / TIME_TO_REAL(pt)); END_IF;
  out := am * 0.5 *  temp + os;

  (* boolean output Q *)
  q := NOT sign_R(temp);

  (* From OSCAT Library, www.oscat.de *)
  (* T_PLC_MS, SIGN_R required*)
END_FUNCTION_BLOCK

FUNCTION STAIR : REAL
  VAR_INPUT
    X : REAL;
    _D : REAL;
  END_VAR

  IF _D > 0.0 THEN
  	STAIR := DINT_TO_REAL(REAL_TO_DINT(X / _D)) * _D;
  ELSE
  	STAIR := X;
  END_IF;

  (* From OSCAT Library, www.oscat.de *)
END_FUNCTION

FUNCTION_BLOCK SINE_TO_STAIR
  VAR
    genSin : GEN_SIN;
  END_VAR
  VAR_OUTPUT
    outputSignal : REAL;
  END_VAR

  genSin(PT := T#10s, AM := 10.0, OS := 5.0, DL := 0.0);
  (*stair(X := genSin.OUT, _D := 2.3);*)
  outputSignal := STAIR(X := genSin.OUT, _D := 2.3);

END_FUNCTION_BLOCK

PROGRAM program0
  VAR
    dummy_var : BOOL;
    mySineToStair : SINE_TO_STAIR;
  END_VAR

  mySineToStair();
END_PROGRAM


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#1s0ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : program0;
  END_RESOURCE
END_CONFIGURATION
