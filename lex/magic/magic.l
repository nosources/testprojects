%s MAGIC

%%

<MAGIC>.+ {BEGIN 0; printf("MAGIC:");ECHO;}
magic {BEGIN MAGIC; printf("start magic:"); ECHO;}
%%

main()
{
	yylex();
}
