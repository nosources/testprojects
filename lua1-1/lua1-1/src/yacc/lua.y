%{

char *rcs_luastx = "$Id: lua.stx,v 2.4 1994/04/20 16:22:21 celes Exp $";

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mm.h"

#include "opcode.h"
#include "hash.h"
#include "inout.h"
#include "table.h"
#include "lua.h"

#define LISTING 0

#ifndef GAPCODE
#define GAPCODE 50
#endif
static Word   maxcode;
static Word   maxmain;
static Word   maxcurr ;
static Byte  *code = NULL;
static Byte  *initcode;
static Byte  *basepc;
static Word   maincode;
static Word   pc;

#define MAXVAR 32
static long    varbuffer[MAXVAR];    /* variables in an assignment list;
				it's long to store negative Word values */
static int     nvarbuffer=0;	     /* number of variables at a list */

static Word    localvar[STACKGAP];   /* store local variable names */
static int     nlocalvar=0;	     /* number of local variables */

#define MAXFIELDS FIELDS_PER_FLUSH*2
static Word    fields[MAXFIELDS];     /* fieldnames to be flushed */
static int     nfields=0;
static int     ntemp;		     /* number of temporary var into stack */
static int     err;		     /* flag to indicate error */

/* Internal functions */

static void code_byte (Byte c)
{
 if (pc>maxcurr-2)  /* 1 byte free to code HALT of main code */
 {
  maxcurr += GAPCODE;
  basepc = (Byte *)realloc(basepc, maxcurr*sizeof(Byte));
  if (basepc == NULL)
  {
   lua_error ("not enough memory");
   err = 1;
  }
 }
 basepc[pc++] = c;
}

static void code_word (Word n)
{
 CodeWord code;
 code.w = n;
 code_byte(code.m.c1);
 code_byte(code.m.c2);
}

static void code_float (float n)
{
 CodeFloat code;
 code.f = n;
 code_byte(code.m.c1);
 code_byte(code.m.c2);
 code_byte(code.m.c3);
 code_byte(code.m.c4);
}

static void code_word_at (Byte *p, Word n)
{
 CodeWord code;
 code.w = n;
 *p++ = code.m.c1;
 *p++ = code.m.c2;
}

static void push_field (Word name)
{
  if (nfields < STACKGAP-1)
    fields[nfields++] = name;
  else
  {
   lua_error ("too many fields in a constructor");
   err = 1;
  }
}

static void flush_record (int n)
{
  int i;
  if (n == 0) return;
  code_byte(STORERECORD);
  code_byte(n);
  for (i=0; i<n; i++)
    code_word(fields[--nfields]);
  ntemp -= n;
}

static void flush_list (int m, int n)
{
  if (n == 0) return;
  if (m == 0)
    code_byte(STORELIST0); 
  else
  {
    code_byte(STORELIST);
    code_byte(m);
  }
  code_byte(n);
  ntemp-=n;
}

static void incr_ntemp (void)
{
 if (ntemp+nlocalvar+MAXVAR+1 < STACKGAP)
  ntemp++;
 else
 {
  lua_error ("stack overflow");
  err = 1;
 }
}

static void add_nlocalvar (int n)
{
 if (ntemp+nlocalvar+MAXVAR+n < STACKGAP)
  nlocalvar += n;
 else
 {
  lua_error ("too many local variables or expression too complicate");
  err = 1;
 }
}

static void incr_nvarbuffer (void)
{
 if (nvarbuffer < MAXVAR-1)
  nvarbuffer++;
 else
 {
  lua_error ("variable buffer overflow");
  err = 1;
 }
}

static void code_number (float f)
{ Word i = (Word)f;
  if (f == (float)i)  /* f has an (short) integer value */
  {
   if (i <= 2) code_byte(PUSH0 + i);
   else if (i <= 255)
   {
    code_byte(PUSHBYTE);
    code_byte(i);
   }
   else
   {
    code_byte(PUSHWORD);
    code_word(i);
   }
  }
  else
  {
   code_byte(PUSHFLOAT);
   code_float(f);
  }
  incr_ntemp();
}

%}


%union 
{
 int   vInt;
 long  vLong;
 float vFloat;
 char *pChar;
 Word  vWord;
 Byte *pByte;
}

%start functionlist

%token WRONGTOKEN
%token NIL
%token IF THEN ELSE ELSEIF WHILE DO REPEAT UNTIL END
%token RETURN
%token LOCAL
%token <vFloat> NUMBER
%token <vWord>  FUNCTION STRING
%token <pChar>   NAME 
%token <vInt>   DEBUG

%type <vWord> PrepJump
%type <vInt>  expr, exprlist, exprlist1, varlist1, typeconstructor
%type <vInt>  fieldlist, localdeclist
%type <vInt>  ffieldlist, ffieldlist1
%type <vInt>  lfieldlist, lfieldlist1
%type <vLong> var, objectname


%left AND OR
%left '=' NE '>' '<' LE GE
%left CONC
%left '+' '-'
%left '*' '/'
%left UNARY NOT


%% /* beginning of rules section */


functionlist : /* empty */
        | functionlist              {
                                        pc=maincode; basepc=initcode; maxcurr=maxmain;
                                        nlocalvar=0;
                                    }
	      stat sc
                                    {
                                        maincode=pc; initcode=basepc; maxmain=maxcurr;
                                    }
        | functionlist function
        | functionlist setdebug
	     ;
	     
function : FUNCTION NAME            {
                                        if (code == NULL)	/* first function */
                                        {
                                            code = (Byte *) calloc(GAPCODE, sizeof(Byte));
                                            if (code == NULL)
                                            {
                                                lua_error("not enough memory");
                                                err = 1;
                                            }
                                            maxcode = GAPCODE;
                                        }
                                        pc=0; basepc=code; maxcurr=maxcode;
                                        nlocalvar=0;
                                        $<vWord>$ = lua_findsymbol($2);
                                    }
	       '(' parlist ')' 
                                    {
                                        if (lua_debug)
                                        {
                                            code_byte(SETFUNCTION);
                                            code_word(lua_nfile-1);
                                            code_word($<vWord>3);
                                        }
                                        lua_codeadjust (0);
                                    }
            block
            END
                                    {
                                        if (lua_debug) code_byte(RESET);
                                        code_byte(RETCODE); code_byte(nlocalvar);
                                        s_tag($<vWord>3) = T_FUNCTION;
                                        s_bvalue($<vWord>3) = calloc (pc, sizeof(Byte));
                                        if (s_bvalue($<vWord>3) == NULL)
                                        {
                                            lua_error("not enough memory");
                                            err = 1;
                                        }
                                        memcpy (s_bvalue($<vWord>3), basepc, pc*sizeof(Byte));
                                        code = basepc; maxcode=maxcurr;
#if LISTING
                                        PrintCode(code,code+pc);
#endif
                                    }
	       ;

statlist : /* empty */
	 | statlist stat sc
	 ;

stat :                              {
                                        ntemp = 0;
                                        if (lua_debug)
                                        {
                                            code_byte(SETLINE); code_word(lua_linenumber);
                                        }
                                    }
	   stat1
		
sc	 : /* empty */ | ';' ;


stat1 : IF expr1 THEN PrepJump block PrepJump elsepart END
                                    {
                                        {
                                            Word elseinit = $6+sizeof(Word)+1;
                                            if (pc - elseinit == 0)		/* no else */
                                            {
                                                pc -= sizeof(Word)+1;
                                                elseinit = pc;
                                            }
                                            else
                                            {
                                                basepc[$6] = JMP;
                                                code_word_at(basepc+$6+1, pc - elseinit);
                                            }
                                            basepc[$4] = IFFJMP;
                                            code_word_at(basepc+$4+1,elseinit-($4+sizeof(Word)+1));
                                        }
                                    }
     
       | WHILE {$<vWord>$=pc;} expr1 DO PrepJump block PrepJump END
     	
                                    {
                                        basepc[$5] = IFFJMP;
                                        code_word_at(basepc+$5+1, pc - ($5 + sizeof(Word)+1));
        
                                        basepc[$7] = UPJMP;
                                        code_word_at(basepc+$7+1, pc - ($<vWord>2));
                                    }
     
       | REPEAT {$<vWord>$=pc;} block UNTIL expr1 PrepJump
     	
                                    {
                                        basepc[$6] = IFFUPJMP;
                                        code_word_at(basepc+$6+1, pc - ($<vWord>2));
                                    }


       | varlist1 '=' exprlist1
                                    {
                                        {
                                            int i;
                                            if ($3 == 0 || nvarbuffer != ntemp - $1 * 2)
                                            lua_codeadjust ($1 * 2 + nvarbuffer);
                                            for (i=nvarbuffer-1; i>=0; i--)
                                                lua_codestore (i);
                                            if ($1 > 1 || ($1 == 1 && varbuffer[0] != 0))
                                                lua_codeadjust (0);
                                        }
                                    }
       | functioncall               { lua_codeadjust (0); }
       | typeconstructor            { lua_codeadjust (0); }
       | LOCAL localdeclist decinit { add_nlocalvar($2); lua_codeadjust (0); }
       ;

elsepart : /* empty */
        | ELSE block
        | ELSEIF expr1 THEN PrepJump block PrepJump elsepart
                                    {
                                        {
                                            Word elseinit = $6+sizeof(Word)+1;
                                            if (pc - elseinit == 0)		/* no else */
                                            {
                                                pc -= sizeof(Word)+1;
                                                elseinit = pc;
                                            }
                                            else
                                            {
                                                basepc[$6] = JMP;
                                                code_word_at(basepc+$6+1, pc - elseinit);
                                            }
                                            basepc[$4] = IFFJMP;
                                            code_word_at(basepc+$4+1, elseinit - ($4 + sizeof(Word)+1));
                                        }
                                    }
         ;
     
block : {$<vInt>$ = nlocalvar;} statlist {ntemp = 0;} ret
                                    {
                                        if (nlocalvar != $<vInt>1)
                                        {
                                            nlocalvar = $<vInt>1;
                                            lua_codeadjust (0);
                                        }
                                    }
         ;

ret	: /* empty */
        | { if (lua_debug){code_byte(SETLINE);code_word(lua_linenumber);}}
          RETURN  exprlist sc 	
          { 
           if (lua_debug) code_byte(RESET); 
           code_byte(RETCODE); code_byte(nlocalvar);
          }
	;

PrepJump : /* empty */
	 { 
	  $$ = pc;
	  code_byte(0);		/* open space */
	  code_word (0);
         }
	   
expr1	 : expr { if ($1 == 0) {lua_codeadjust (ntemp+1); incr_ntemp();}}
	 ;
				
expr :	'(' expr ')'    { $$ = $2; }
     |	expr1 '=' expr1	{ code_byte(EQOP);   $$ = 1; ntemp--;}
     |	expr1 '<' expr1	{ code_byte(LTOP);   $$ = 1; ntemp--;}
     |	expr1 '>' expr1	{ code_byte(LEOP); code_byte(NOTOP); $$ = 1; ntemp--;}
     |	expr1 NE  expr1	{ code_byte(EQOP); code_byte(NOTOP); $$ = 1; ntemp--;}
     |	expr1 LE  expr1	{ code_byte(LEOP);   $$ = 1; ntemp--;}
     |	expr1 GE  expr1	{ code_byte(LTOP); code_byte(NOTOP); $$ = 1; ntemp--;}
     |	expr1 '+' expr1 { code_byte(ADDOP);  $$ = 1; ntemp--;}
     |	expr1 '-' expr1 { code_byte(SUBOP);  $$ = 1; ntemp--;}
     |	expr1 '*' expr1 { code_byte(MULTOP); $$ = 1; ntemp--;}
     |	expr1 '/' expr1 { code_byte(DIVOP);  $$ = 1; ntemp--;}
     |	expr1 CONC expr1 { code_byte(CONCOP);  $$ = 1; ntemp--;}
     |	'+' expr1 %prec UNARY	{ $$ = 1; }
     |	'-' expr1 %prec UNARY	{ code_byte(MINUSOP); $$ = 1;}
     | typeconstructor { $$ = $1; }
     |  '@' '(' dimension ')'
     { 
      code_byte(CREATEARRAY);
      $$ = 1;
     }
     |	var             { lua_pushvar ($1); $$ = 1;}
     |	NUMBER          { code_number($1); $$ = 1; }
     |	STRING
     {
      code_byte(PUSHSTRING);
      code_word($1);
      $$ = 1;
      incr_ntemp();
     }
     |	NIL		{code_byte(PUSHNIL); $$ = 1; incr_ntemp();}
     |	functioncall
     {
      $$ = 0;
      if (lua_debug)
      {
       code_byte(SETLINE); code_word(lua_linenumber);
      }
     }
     |	NOT expr1	{ code_byte(NOTOP);  $$ = 1;}
     |	expr1 AND PrepJump {code_byte(POP); ntemp--;} expr1
     { 
      basepc[$3] = ONFJMP;
      code_word_at(basepc+$3+1, pc - ($3 + sizeof(Word)+1));
      $$ = 1;
     }
     |	expr1 OR PrepJump {code_byte(POP); ntemp--;} expr1	
     { 
      basepc[$3] = ONTJMP;
      code_word_at(basepc+$3+1, pc - ($3 + sizeof(Word)+1));
      $$ = 1;
     }
     ;

typeconstructor: '@'  
     {
      code_byte(PUSHBYTE);
      $<vWord>$ = pc; code_byte(0);
      incr_ntemp();
      code_byte(CREATEARRAY);
     }
      objectname fieldlist 
     {
      basepc[$<vWord>2] = $4; 
      if ($3 < 0)	/* there is no function to be called */
      {
       $$ = 1;
      }
      else
      {
       lua_pushvar ($3+1);
       code_byte(PUSHMARK);
       incr_ntemp();
       code_byte(PUSHOBJECT);
       incr_ntemp();
       code_byte(CALLFUNC); 
       ntemp -= 4;
       $$ = 0;
       if (lua_debug)
       {
        code_byte(SETLINE); code_word(lua_linenumber);
       }
      }
     }
         ;

dimension    : /* empty */	{ code_byte(PUSHNIL); incr_ntemp();}
	     | expr1
	     ;
	     
functioncall : functionvalue  {code_byte(PUSHMARK); $<vInt>$ = ntemp; incr_ntemp();}
                '(' exprlist ')' { code_byte(CALLFUNC); ntemp = $<vInt>2-1;}

functionvalue : var {lua_pushvar ($1); } 
	      ;
		
exprlist  :	/* empty */		{ $$ = 1; }
	  |	exprlist1		{ $$ = $1; }
	  ;
		
exprlist1 :	expr			{ $$ = $1; }
	  |	exprlist1 ',' {if (!$1){lua_codeadjust (ntemp+1); incr_ntemp();}} 
                 expr {$$ = $4;}
	  ;

parlist  :	/* empty */
	  |	parlist1
	  ;
		
parlist1 :	NAME		  
		{
		 localvar[nlocalvar]=lua_findsymbol($1); 
		 add_nlocalvar(1);
		}
	  |	parlist1 ',' NAME 
		{
		 localvar[nlocalvar]=lua_findsymbol($3); 
		 add_nlocalvar(1);
		}
	  ;
		
objectname :	/* empty */ 	{$$=-1;}
	   |	NAME		{$$=lua_findsymbol($1);}
	   ;
	   
fieldlist  : '{' ffieldlist '}'  
	      { 
	       flush_record($2%FIELDS_PER_FLUSH); 
	       $$ = $2;
	      }
           | '[' lfieldlist ']'  
	      { 
	       flush_list($2/FIELDS_PER_FLUSH, $2%FIELDS_PER_FLUSH);
	       $$ = $2;
     	      }
	   ;

ffieldlist : /* empty */   { $$ = 0; }
           | ffieldlist1   { $$ = $1; }
           ;

ffieldlist1 : ffield			{$$=1;}
	   | ffieldlist1 ',' ffield	
		{
		  $$=$1+1;
		  if ($$%FIELDS_PER_FLUSH == 0) flush_record(FIELDS_PER_FLUSH);
		}
	   ; 

ffield      : NAME {$<vWord>$ = lua_findconstant($1);} '=' expr1 
	      { 
	       push_field($<vWord>2);
	      }
           ;

lfieldlist : /* empty */   { $$ = 0; }
           | lfieldlist1   { $$ = $1; }
           ;

lfieldlist1 : expr1  {$$=1;}
	    | lfieldlist1 ',' expr1
		{
		  $$=$1+1;
		  if ($$%FIELDS_PER_FLUSH == 0) 
		    flush_list($$/FIELDS_PER_FLUSH - 1, FIELDS_PER_FLUSH);
		}
            ;

varlist1  :	var			
	  {
	   nvarbuffer = 0; 
           varbuffer[nvarbuffer] = $1; incr_nvarbuffer();
	   $$ = ($1 == 0) ? 1 : 0;
	  }
	  |	varlist1 ',' var	
	  { 
           varbuffer[nvarbuffer] = $3; incr_nvarbuffer();
	   $$ = ($3 == 0) ? $1 + 1 : $1;
	  }
	  ;
		
var	  :	NAME
                                    {
                                        Word s = lua_findsymbol($1);
                                        int local = lua_localname (s);
                                        if (local == -1)	/* global var */
                                            $$ = s + 1;		/* return positive value */
                                        else
                                            $$ = -(local+1);		/* return negative value */
                                    }
	  
	  |	var {lua_pushvar ($1);} '[' expr1 ']' 
	  {
	   $$ = 0;		/* indexed variable */
	  }
	  |	var {lua_pushvar ($1);} '.' NAME
	  {
	   code_byte(PUSHSTRING);
	   code_word(lua_findconstant($4)); incr_ntemp();
	   $$ = 0;		/* indexed variable */
	  }
	  ;
		
localdeclist  : NAME {localvar[nlocalvar]=lua_findsymbol($1); $$ = 1;}
     	  | localdeclist ',' NAME 
	    {
	     localvar[nlocalvar+$1]=lua_findsymbol($3); 
	     $$ = $1+1;
	    }
	  ;
		
decinit	  : /* empty */
	  | '=' exprlist1
	  ;
	  
setdebug  : DEBUG {lua_debug = $1;}

%%

/*
** Search a local name and if find return its index. If do not find return -1
*/
static int lua_localname (Word n)
{
 int i;
 for (i=nlocalvar-1; i >= 0; i--)
  if (n == localvar[i]) return i;	/* local var */
 return -1;		        /* global var */
}

/*
** Push a variable given a number. If number is positive, push global variable
** indexed by (number -1). If negative, push local indexed by ABS(number)-1.
** Otherwise, if zero, push indexed variable (record).
*/
static void lua_pushvar (long number)
{ 
 if (number > 0)	/* global var */
 {
  code_byte(PUSHGLOBAL);
  code_word(number-1);
  incr_ntemp();
 }
 else if (number < 0)	/* local var */
 {
  number = (-number) - 1;
  if (number < 10) code_byte(PUSHLOCAL0 + number);
  else
  {
   code_byte(PUSHLOCAL);
   code_byte(number);
  }
  incr_ntemp();
 }
 else
 {
  code_byte(PUSHINDEXED);
  ntemp--;
 }
}

static void lua_codeadjust (int n)
{
 code_byte(ADJUST);
 code_byte(n + nlocalvar);
}

static void lua_codestore (int i)
{
 if (varbuffer[i] > 0)		/* global var */
 {
  code_byte(STOREGLOBAL);
  code_word(varbuffer[i]-1);
 }
 else if (varbuffer[i] < 0)      /* local var */
 {
  int number = (-varbuffer[i]) - 1;
  if (number < 10) code_byte(STORELOCAL0 + number);
  else
  {
   code_byte(STORELOCAL);
   code_byte(number);
  }
 }
 else				  /* indexed var */
 {
  int j;
  int upper=0;     	/* number of indexed variables upper */
  int param;		/* number of itens until indexed expression */
  for (j=i+1; j <nvarbuffer; j++)
   if (varbuffer[j] == 0) upper++;
  param = upper*2 + i;
  if (param == 0)
   code_byte(STOREINDEXED0);
  else
  {
   code_byte(STOREINDEXED);
   code_byte(param);
  }
 }
}

void yyerror (char *s)
{
 static char msg[256];
 sprintf (msg,"%s near \"%s\" at line %d in file \"%s\"",
          s, lua_lasttext (), lua_linenumber, lua_filename());
 lua_error (msg);
 err = 1;
}

int yywrap (void)
{
 return 1;
}


/*
** Parse LUA code and execute global statement.
** Return 0 on success or 1 on error.
*/
int lua_parse (void)
{
 Byte *init = initcode = (Byte *) calloc(GAPCODE, sizeof(Byte));
 maincode = 0; 
 maxmain = GAPCODE;
 if (init == NULL)
 {
  lua_error("not enough memory");
  return 1;
 }
 err = 0;
 if (yyparse () || (err==1)) return 1;
 initcode[maincode++] = HALT;
 init = initcode;
#if LISTING
 PrintCode(init,init+maincode);
#endif
 if (lua_execute (init)) return 1;
 free(init);
 return 0;
}
#endif

