FUNCTION_BLOCK SINE_TO_STAIR
VAR_INPUT
END_VAR
VAR_OUTPUT
  outputSignal: REAL;
END_VAR
VAR
  genSin: GEN_SIN;
  stair: STAIR;
END_VAR
genSin(PT := T#10S, AM := 10, OS := 5, DL := 0);
stair(X := genSin.OUT, D := 2.3);
outputSignal := stair.OUTPUT;
END_FUNCTION_BLOCK

