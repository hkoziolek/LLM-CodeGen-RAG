FUNCTION_BLOCK fb_SampleAndAverage
VAR_INPUT
    Signal_In: REAL;
    PT: TIME := T#1s;
    N: INT := 8;
END_VAR

VAR_OUTPUT
    AVG: REAL;
END_VAR

VAR
    fb_SH_1: SH_1;
    fb_FT_AVG: FT_AVG; 
END_VAR

fb_SH_1(IN := Signal_In, PT := PT);
fb_FT_AVG(IN := fb_SH_1.OUT, N := N);
AVG := fb_FT_AVG.OutputREAL;
END_FUNCTION_BLOCK

