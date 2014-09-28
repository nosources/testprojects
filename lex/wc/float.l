%{

%}
%%

-?(([0-9]+)|([0-9]*\.[0-9]+))	{ printf("%s is a number\n",yytext); }
.	;
%%

main(){
	yylex();
}
