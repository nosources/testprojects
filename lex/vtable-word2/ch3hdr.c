#include "ch3hdr.h"
#include <string.h>
struct symtable *symlook(char *s)
{
	struct symtable *iterator = symtable;
	for(; iterator < &symtable[NSYMS]; iterator++){
		if (iterator->name && !strcmp(iterator->name, s)){
			return iterator;
		}
		if (!iterator->name){
			iterator->name = strdup(s);
			return iterator;
		}
	}
	yyerror("too many symbols");
	exit(1);
}