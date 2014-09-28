%{
#include "y.tab.h"
extern int yylval;
%}
%%
print {printf("\ntest lex print\n"); return PRINT;}
[0-9]+ {printf("\ntest lex NUMBER\n");yylval = atoi(yytext);  return NUMBER;}
[ \t] ;
\n return 0;
. {printf("\ntest lex %s", yytext); return yytext[0];} 
%%
