%{
#include <stdio.h>
double vbltable[26];
%}
%union{
	double dval;
	int vblno;
}
%token PRINT
%token <vblno> NAME
%token <dval> NUMBER

%type <dval> expression

%left '+' '-'
%left '*' '/'


%%
paragraph:
	paragraph statement '\n'
	|statement '\n'
	;
statement: 
	PRINT expression		{
								printf("\ntest yacc PRINT expression\n");
								printf("result is %lf", $2);
							}
	|NAME '=' expression 	{
								printf("\ntest yacc = expression\n");
								vbltable[$1] = $3;
							}
	;

expression: 
	expression '*' expression 	{
								printf("\ntest yacc expression + expression\n");
								$$ = $1 * $3;
							}
	|expression '/' expression 	{
								printf("\ntest yacc expression + expression\n");
								$$ = $1 / $3;
							}
	|expression '+' expression 	{
								printf("\ntest yacc expression + expression\n");
								$$ = $1 + $3;
							}
	|expression '-' expression 	{
								printf("\ntest yacc expression + expression\n");
								$$ = $1 - $3;
							}
	|NUMBER 				{
								printf("\ntest yacc NUMBER\n");
								$$ = $1;
							} 
	|NAME					{
								$$ = vbltable[$1];
							}
	;

%%