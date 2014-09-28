%{
#include <stdio.h>
%}

%token PRINT NUMBER

%left '+' '-'
%left '*' '/'
%%
statement: 
	PRINT expression		{
								printf("\ntest yacc PRINT expression\n");
								printf("result is %d", $2);
							}
	|expression 			{
								printf("\ntest yacc expression\n");
								printf("%d is the result", $1);
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
