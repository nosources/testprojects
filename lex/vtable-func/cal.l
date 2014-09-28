%{
#include "y.tab.h"
#include "ch3hdr.h"
#include <math.h>
%}
%%
print {printf("\ntest lex print\n"); return PRINT;}
sqrt {printf("\ntest lex sqrt\n"); return SQRT;}
[0-9]+ |
[0-9]*\.[0-9]+ {printf("\ntest lex NUMBER\n");yylval.dval = atof(yytext);  return NUMBER;}
[ \t] ;
[a-zA-Z][a-zA-Z0-9]*		{
								printf("\ntest lex %s", yytext);
								yylval.symble = symlook(yytext);
								return NAME;
							}
"$"  {return 0;}
\n |
. {printf("\ntest lex %s", yytext); return yytext[0];} 
%%
