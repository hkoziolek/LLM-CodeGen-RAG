FUNCTION T_PLC_US : UDINT
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

  {extern unsigned long __tick;
  extern unsigned long long common_ticktime__;
  unsigned long long ticktime_ms = (common_ticktime__)/1000000;
  UDINT plc_time = (UDINT)(ticktime_ms * (unsigned long long)__tick);
  TX = plc_time}

  T_PLC_US := tx*1000;
  IF debug THEN
  	T_PLC_US := (DWORD_TO_UDINT(SHL(UDINT_TO_DWORD(T_PLC_US),N) OR SHL(temp,N))-1) + OFFSET;
  END_IF;

  (* Original Code:
  tx := TIME();
  T_PLC_US := TIME_TO_DWORD(Tx)*1000;
  IF debug THEN
  	T_PLC_US := (SHL(T_PLC_US,N) OR SHL(DWORD#1,N)-1) + OFFSET;
  END_IF;
  *)

  (* From OSCAT library, www.oscat.de

  this is a temporary T_PLC_US FB until OpenPLC gets it´s own time() functionality *)

  (* PLC_TIME and Global variables PLC_SCAN_CYCL and PLC_CYCL_TIME required *)
END_FUNCTION

FUNCTION_BLOCK FT_PIWL
  VAR_INPUT
    IN : REAL;
    KP : REAL := 1.0;
    KI : REAL := 1.0;
    LIM_L : REAL := -1.0E38;
    LIM_H : REAL := 1.0E38;
    RST : BOOL;
  END_VAR
  VAR_OUTPUT
    Y : REAL;
    LIM : BOOL;
  END_VAR
  VAR
    init : BOOL;
    tx : UDINT;
    tc : REAL;
    t_last : UDINT;
    in_last : REAL;
    i : REAL;
    p : REAL;
  END_VAR

  IF NOT init OR RST THEN
  	init := TRUE;
  	in_last := in;
  		t_last := T_PLC_US(en:=true);
  	i := 0.0;
  	tc := 0.0;
  ELSE
  	(* read last cycle time in Microseconds *)
  		tx := T_PLC_US(en:=true);
  	tc := UDINT_TO_REAL(tx - t_last);
  	t_last := tx;

  	(* calculate proportional part *)
  	p := KP * IN;

  	(* run integrator *)
  	i := (IN + in_last) * 5.0E-7 * KI * tc + i;
  	in_last := IN;

  	(* calculate output Y *)
  	Y := p + i;

  	(* check output for limits *)
  	IF Y >= LIM_H THEN
  		Y := LIM_H;
  		IF ki <> 0.0 THEN
  			i := LIM_H - p;
  		ELSE
  			i := 0.0;
  		END_IF;
  		LIM := TRUE;
  	ELSIF Y <= LIM_L THEN
  		Y := LIM_L;
  		IF ki <> 0.0 THEN
  			i := LIM_L - p;
  		ELSE
  			i := 0.0;
  		END_IF;
  		LIM := TRUE;
  	ELSE
  		LIM := FALSE;
  	END_IF;
  END_IF;

  (* From OSCAT Library, www.oscat.de *)
  (* T_PLC_US required *)
END_FUNCTION_BLOCK

FUNCTION_BLOCK FT_DERIV
  VAR_INPUT
    IN : REAL;
    K : REAL := 1.0;
    RUN : BOOL := TRUE;
  END_VAR
  VAR_OUTPUT
    OUT : REAL;
  END_VAR
  VAR
    old : REAL;
    tx : UDINT;
    last : UDINT;
    init : BOOL;
    tc : REAL;
  END_VAR

  tx:= T_PLC_US(en:=true);
  tc := UDINT_TO_REAL(tx - last);

  (* init on firsat startup *)
  IF NOT init THEN
  	init := TRUE;
  	old := in;
  ELSIF run AND tc > 0.0 THEN
  	out := (in - old) / tc * 1000000.0 * K;
  	old := in;
  ELSE
  	out := 0.0;
  END_IF;

  last := tx;

  (* From OSCAT Library, www.oscat.de *)
  (* T_PLC_US, required *)
END_FUNCTION_BLOCK

FUNCTION_BLOCK FT_PIDWL
  VAR_INPUT
    IN : REAL;
    KP : REAL := 1.0;
    TN : REAL := 1.0;
    TV : REAL := 1.0;
    LIM_L : REAL := -1.0E38;
    LIM_H : REAL := 1.0E38;
    RST : BOOL;
  END_VAR
  VAR_OUTPUT
    Y : REAL;
    LIM : BOOL;
  END_VAR
  VAR
    piwl : FT_PIWL;
    diff : FT_DERIV;
  END_VAR

  IF rst THEN
  	piwl(rst := TRUE);
  	piwl.RST := FALSE;
  ELSE
  	(* run PIWL controller first *)
  	(* we need to check if TN = 0 and do alternative calls *)
  	IF TN = 0.0 THEN
  		piwl(in := IN * KP, KP := 1.0, KI := 0.0, LIM_L := LIM_L, LIM_H := LIM_H);
  	ELSE
  		piwl(in := IN * KP, KP := 1.0, KI := 1.0 / TN, LIM_L := LIM_L, LIM_H := LIM_H);
  	END_IF;

  	(* run differentiator and add_to_output *)
  	diff(IN := IN, K := KP * TV);
  	Y := piwl.Y + diff.out;

  	(* limit the output *)
  	IF Y < LIM_L THEN
  		LIM := TRUE;
  		Y := LIM_L;
  	ELSIF Y > LIM_H THEN
  		LIM := TRUE;
  		Y := LIM_H;
  	ELSE
  		LIM := FALSE;
  	END_IF;
  END_IF;



  (* From OSCAT Library, www.oscat.de *)
  (* T_PLC_US, FT_DERIV required *)
END_FUNCTION_BLOCK

FUNCTION_BLOCK CTRL_OUT
  VAR_INPUT
    CI : REAL;
    OFFSET : REAL;
    MAN_IN : REAL;
    LIM_L : REAL;
    LIM_H : REAL;
    MANUAL : BOOL;
  END_VAR
  VAR_OUTPUT
    Y : REAL;
    LIM : BOOL;
  END_VAR

  Y := SEL(manual, CI, MAN_IN) + OFFSET;

  (* Limit the output *)
  IF Y >= LIM_H THEN
  	Y := LIM_H;
  	LIM := TRUE;
  ELSIF Y <= lim_L THEN
  	Y := LIM_L;
  	LIM := TRUE;
  ELSE
  	LIM := FALSE;
  END_IF;

  (* From OSCAT Library, www.oscat.de *)
END_FUNCTION_BLOCK

FUNCTION DEAD_ZONE : REAL
  VAR_INPUT
    X : REAL;
    L : REAL;
  END_VAR

  IF ABS(x) > L THEN
  	dead_zone := X;
  ELSE
  	DEAD_ZONE := 0.0;
  END_IF;

  (* From OSCAT Library, www.oscat.de *)
END_FUNCTION

FUNCTION CTRL_IN : REAL
  VAR_INPUT
    SET_POINT : REAL;
    ACTUAL : REAL;
    NOISE : REAL;
  END_VAR

  CTRL_IN := DEAD_ZONE(SET_POINT - ACTUAL, NOISE);

  (* From OSCAT Library, www.oscat.de *)
  (* DEAD_ZONE required *)
END_FUNCTION

FUNCTION_BLOCK CTRL_PID
  VAR_INPUT
    ACT : REAL;
    SET : REAL;
    SUP : REAL;
    OFS : REAL;
    M_I : REAL;
    MAN : BOOL;
    RST : BOOL := FALSE;
    KP : REAL := 1.0;
    TN : REAL := 1.0;
    TV : REAL := 1.0;
    LL : REAL := -1000.0;
    LH : REAL := 1000.0;
  END_VAR
  VAR_OUTPUT
    Y : REAL;
    DIFF : REAL;
    LIM : BOOL;
  END_VAR
  VAR
    _pid : FT_PIDWL;
    co : CTRL_OUT;
  END_VAR

  DIFF := CTRL_IN(SET, ACT, SUP);
  _pid(in := DIFF, kp := KP, tn := TN, tv := TV, lim_l := LL, lim_h := LH, rst := RST);
  co(ci := _pid.Y, OFFSET := OFS, man_in := M_I, lim_l := LL, lim_h := LH, manual := MAN);
  Y := co.Y;
  LIM := co.LIM;


  (* From OSCAT Library, www.oscat.de *)
  (* CTRL_IN, FT_PIDWL, CTRL_out reauired *)
END_FUNCTION_BLOCK

FUNCTION_BLOCK PID_Controller
  VAR_INPUT
    ACT : REAL;
    SET : REAL;
  END_VAR
  VAR
    ctrl_pid1 : CTRL_PID;
    ctrl_out1 : CTRL_OUT;
  END_VAR
  VAR_OUTPUT
    Y : REAL;
    DIFF : REAL;
    LIM : BOOL;
  END_VAR

  ctrl_pid1(ACT := ACT, 
            SET := SET, 
            SUP := 0.0, 
            OFS := 0.0, 
            M_I := 0.0, 
            MAN := FALSE, 
            RST := FALSE, 
            KP := 1.0, 
            TN := 1.0, 
            TV := 1.0, 
            LL := -100.0, 
            LH := 100.0);
  Y := ctrl_pid1.Y;

  (*

  ctrl_out1(CI := ctrl_pid1.Y, 
            MAN_IN := 0.0, 
            MANUAL := FALSE, 
            LIM_L := -100.0, 
            LIM_H := 100.0);

  Y := ctrl_out1.Y;
  DIFF := ctrl_pid1.DIFF;
  LIM := ctrl_pid1.LIM;
  *)

END_FUNCTION_BLOCK

FUNCTION_BLOCK AMMONIUM_NITRATE_TEMP_CONTROL
  VAR_INPUT
    temp_actual : REAL;
    manual_mode : BOOL;
    manual_input : REAL;
  END_VAR
  VAR_OUTPUT
    control_output : REAL;
  END_VAR
  VAR
    set_point : REAL := 180.0;
    kp : REAL := 50.0;
    ki : REAL := 1.2;
    kd : REAL := 10.0;
    lower_limit : REAL := -100.0;
    upper_limit : REAL := 100.0;
    pidcontroller : CTRL_PID;
    timer : TON;
    timer_done : BOOL;
  END_VAR

  timer(IN:=NOT manual_mode, PT:=T#10S);
  timer_done := timer.Q;

  IF timer_done THEN
      pidcontroller(ACT:=temp_actual, 
                     SET:=set_point, 
                     KP:=kp, 
                     TN:=kp/ki, 
                     TV:=kd/kp, 
                     LL:=lower_limit, 
                     LH:=upper_limit, 
                     MAN:=manual_mode, 
                     M_I:=manual_input, 
                     RST:=FALSE);
      control_output := pidcontroller.Y;
  ELSE
      control_output := 0.0;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM program0
  VAR
    myACT : REAL := 0.1;
    mySET : REAL := 1.0;
    myPIDController : PID_Controller;
    myPID : AMMONIUM_NITRATE_TEMP_CONTROL;
  END_VAR

  (*
  myPIDController(ACT := myACT, SET := mySET);
  *)

  myPID(temp_actual := myAct,
        manual_mode := FALSE,
        manual_input := 0.0);

  IF myACT < mySET THEN
    myACT := myACT + 0.01;
  ELSIF myACT > mySET THEN
    myACT := myACT - 0.01;
  END_IF;


END_PROGRAM


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#100ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : program0;
  END_RESOURCE
END_CONFIGURATION
