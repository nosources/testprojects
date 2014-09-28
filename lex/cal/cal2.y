%{
#include <stdio.h>
%}

%token PRINT NUMBER
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
	expression '+' mulexp 	{
								printf("\ntest yacc expression + expression\n");
								$$ = $1 + $3;
							}
	|expression '-' mulexp 	{
								printf("\ntest yacc expression - expression\n");
								$$ = $1 - $3;
							}
	|mulexp 				{
								printf("\ntest yacc mulexp\n");
								$$ = $1;
							} 

mulexp:
	|NUMBER '*' NUMBER 		{
								printf("\ntest yacc NUMBER '*' NUMBER\n");
								$$ = $1 * $3;
							}
	|NUMBER '/' NUMBER 		{
								printf("\ntest yacc NUMBER '/' NUMBER\n");
								$$ = $1 / $3;
							}
	|NUMBER 		 		{
								printf("\ntest yacc NUMBER\n");
								$$ = $1;
							}


