FUNCTION INC1 : INT
  VAR_INPUT
    X : INT;
    N : INT;
  END_VAR

  IF X >= N - 1 THEN
  	INC1 := 0;
  ELSE
  	INC1 := X + 1;
  END_IF;
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
  	T_PLC_MS := (SHL(T_PLC_MS,N) OR SHL(DWORD#1,N)-1) + OFFSET;
  END_IF;
  *)

  (* From OSCAT library, www.oscat.de

  this is a temporary T_PLC_MS FB until OpenPLC gets it´s own time() functionality *)

  (* PLC_TIME and Global variables PLC_SCAN_CYCL and PLC_CYCL_TIME required *)
END_FUNCTION

FUNCTION_BLOCK SH_1
  VAR_INPUT
    IN : REAL;
    PT : TIME;
  END_VAR
  VAR_OUTPUT
    OUT : REAL;
    TRIG : BOOL;
  END_VAR
  VAR
    last : TIME;
    tx : TIME;
  END_VAR

  tx:= UDINT_TO_TIME(T_PLC_MS(en:=true));

  IF tx - last >= PT THEN
  	last := tx;
  	out := in;
  	trig := TRUE;
  ELSE
  	trig := FALSE;
  END_IF;

  (* From OSCAT Library, www.oscat.de *)
  (* T_PLC_MS required *)
END_FUNCTION_BLOCK

FUNCTION_BLOCK DELAY
  VAR_INPUT
    IN : REAL;
    N : INT;
    RST : BOOL;
  END_VAR
  VAR_OUTPUT
    OUT : REAL;
  END_VAR
  VAR
    buf : ARRAY [0..31] OF REAL;
    i : INT;
    init : BOOL;
    stop : INT;
  END_VAR

  stop := LIMIT(0,N,32) - 1;
  IF rst OR NOT init THEN
  	init := TRUE;
  	FOR i := 0 TO stop DO buf[i] := in; END_FOR;
  	out := in;
  	i := 0;
  ELSIF stop < 0 THEN
  	out := in;
  ELSE
  	out := buf[i];
  	buf[i] := in;
  	i := INC1(i, N);
  END_IF;

  (* From OSCAT Library, www.oscat.de *)
  (* INC1 required *)
END_FUNCTION_BLOCK

FUNCTION_BLOCK FT_AVG
  VAR_INPUT
    IN : REAL;
    _E : BOOL := TRUE;
    RST : BOOL;
    N : INT := 32;
  END_VAR
  VAR_OUTPUT
    AVG : REAL;
  END_VAR
  VAR
    buff : DELAY;
    i : INT;
    init : BOOL;
  END_VAR

  buff.N := LIMIT(0, N, 32);

  IF NOT init OR rst THEN
  	FOR i := 1 TO N DO
  		buff(in := in);
  	END_FOR;
  	avg := in;
  	init := TRUE;
  ELSIF _E THEN
  	buff(in := in);
  	avg := avg + (in - buff.out ) / INT_TO_REAL(N);
  END_IF;
  (* from OSCAT library www.oscat.de *)
  (* FB FC delay and inc1 requiered *)
END_FUNCTION_BLOCK

FUNCTION_BLOCK SAMPLE_AND_AVERAGE
  VAR_INPUT
    signal_in : REAL;
  END_VAR
  VAR_OUTPUT
    avg_out : REAL;
  END_VAR
  VAR
    sh1 : SH_1;
    ft_avg2 : FT_AVG;
  END_VAR

  sh1(IN := signal_in, PT := T#1S);
  ft_avg2(IN := sh1.OUT, _E := TRUE, N := 8, RST := FALSE);
  avg_out := ft_avg2.AVG;
END_FUNCTION_BLOCK

PROGRAM program0
  VAR
    sampleAndAverage : SAMPLE_AND_AVERAGE;
  END_VAR

  sampleAndAverage(signal_in := 10.0);
END_PROGRAM

FUNCTION_BLOCK MY_FT_AVG
  VAR_INPUT
    Signal_In : REAL;
    PT : TIME;
    N : INT;
  END_VAR
  VAR
    fb_SH_1 : SH_1;
    fb_FT_AVG : FT_AVG;
  END_VAR
  VAR_OUTPUT
    AVG : REAL;
  END_VAR

  fb_SH_1(IN := Signal_In, PT := PT);
  fb_FT_AVG(IN := fb_SH_1.OUT, N := N);
  AVG := fb_FT_AVG.AVG;
END_FUNCTION_BLOCK


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#1s0ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : program0;
  END_RESOURCE
END_CONFIGURATION
