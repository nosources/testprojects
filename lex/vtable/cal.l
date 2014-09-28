%{
#include "y.tab.h"
#include <math.h>
extern double vbltable[26];
%}
%%
print {printf("\ntest lex print\n"); return PRINT;}
[0-9]+ |
[0-9]*\.[0-9]+ {printf("\ntest lex NUMBER\n");yylval.dval = atof(yytext);  return NUMBER;}
[ \t] ;
[a-z] {yylval.vblno = yytext[0] - 'a'; return NAME;}
"$"  {return 0;}
\n |
. {printf("\ntest lex %s", yytext); return yytext[0];} 
%%
