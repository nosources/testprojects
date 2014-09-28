#define NSYMS 20

struct symtable{
	char *name;
	double value;
}symtable[NSYMS];

struct symtable *symlook(char *s);