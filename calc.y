%{
#define _USE_MATH_DEFINES /* Para que las variables PI y Euler funcionen*/
#include <math.h>   /* Para funciones matemáticas, cos(), sin(), etc. */
#include <stdio.h>
#include <stdlib.h>
#include "calc.h"   /* Contiene definición de 'symrec' */

int yylex(void);
void yyerror(const char *s);
void init_table(void);
static void process_pending_load(void);
static void print_prompt_if_interactive(void);

static char *pending_load_filename = NULL;
%}

%union {
    double  val;    /* Para devolver números                          */
    symrec *tptr;   /* Para devolver punteros a la tabla de símbolos  */
    char   *str;    /* Para literales de cadena                       */
}

%token <val>  NUM       /* Número simple en doble precisión */
%token <tptr> VAR FNCT  /* Variable y Función               */
%token <str>  STR       /* Literal de cadena                */

%token CMD_WORKSPACE CMD_CLEAN CMD_CLEAR CMD_QUIT CMD_ECHO CMD_ON CMD_OFF CMD_HELP CMD_LOAD
%type  <val>  exp

%right '='
%left  '-' '+'
%left  '*' '/'
%left  NEG          /* Negación--menos unario */
%right '^'          /* Exponenciación         */

/* A continuación la gramática */
%%
input:    /* vacío */
        | input line
        ;

line:     '\n'                     { print_prompt_if_interactive(); }
    | exp '\n'                 { if (echo_mode) printf("\t%.10g\n", $1); print_prompt_if_interactive(); }
    | exp ';' '\n'             { print_prompt_if_interactive(); }
    | command '\n'             { process_pending_load(); print_prompt_if_interactive(); }
    | command ';' '\n'         { process_pending_load(); print_prompt_if_interactive(); }
    | error '\n'               { yyerrok; print_prompt_if_interactive(); }
        ;

command:  CMD_WORKSPACE                    { print_workspace(); }
        | CMD_CLEAN                        { clean_workspace(NULL); }
        | CMD_CLEAN VAR                    { clean_workspace($2->name); }
        | CMD_CLEAR                        { system("clear"); }
        | CMD_QUIT                         { YYACCEPT; }
        | CMD_ECHO CMD_ON                  { echo_mode = 1; }
        | CMD_ECHO CMD_OFF                 { echo_mode = 0; }
        | CMD_HELP                         { print_help(NULL); }
        | CMD_HELP FNCT                    { print_help($2->name); }
        | CMD_HELP VAR                     { print_help($2->name); }
        | '?'                              { print_help(NULL); }
        | '?' FNCT                         { print_help($2->name); }
        | '?' VAR                          { print_help($2->name); }
        | CMD_LOAD '(' STR ')'             {if (pending_load_filename != NULL)
                                                    {
                                                    free(pending_load_filename);
                                                    }
                                            pending_load_filename = $3;
                                            }
;

exp:      NUM                      { $$ = $1;                          }
        | VAR                      {
                                     if (!$1->initialized) {
                                       fprintf(stderr, "Error: variable '%s' no inicializada\n", $1->name);
                                       YYERROR;
                                     }
                                     $$ = $1->value.var;
                                   }
        | VAR '=' exp              {
                                     if ($1->readonly) {
                                       fprintf(stderr, "Error: constante '%s' no se puede modificar\n", $1->name);
                                       YYERROR;
                                     }
                                     $$ = $3; $1->value.var = $3; $1->initialized = 1;
                                   }
        | FNCT '(' exp ')'         { $$ = (*($1->value.fnctptr))($3);  }
        | exp '+' exp              { $$ = $1 + $3;                     }
        | exp '-' exp              { $$ = $1 - $3;                     }
        | exp '*' exp              { $$ = $1 * $3;                     }
        | exp '/' exp              { $$ = $1 / $3;                     }
        | '-' exp %prec NEG        { $$ = -$2;                         }
        | exp '^' exp              { $$ = pow($1, $3);                 }
        | '(' exp ')'              { $$ = $2;                          }
        ;

/* Fin de la gramática */
%%


/* Evita ejecutar el load_script() demasiado pronto,
así el parse primero consumel el '\n' de load("") y después
cambia el buffer del archivo*/
static void
process_pending_load(void)
{
    if (pending_load_filename != NULL)
    {
        load_script(pending_load_filename);
        free(pending_load_filename);
        pending_load_filename = NULL;
    }
}


/* Printear el promt solo si no está leyendo un archivo*/
static void
print_prompt_if_interactive(void)
{
    if (!is_loading_script())
    {
        printf("> ");
        fflush(stdout);
    }
}

/* --- Tabla de símbolos --- */

/* La tabla de símbolos: una cadena de 'struct symrec'. */
symrec *sym_table = (symrec *)0;

symrec *
putsym(const char *sym_name, int sym_type)
{
    symrec *ptr;
    ptr = (symrec *) malloc(sizeof(symrec));
    ptr->name = (char *) malloc(strlen(sym_name) + 1);
    strcpy(ptr->name, sym_name);
    ptr->type = sym_type;
    ptr->value.var = 0; /* pone valor a 0 incluso si es función */
    ptr->initialized = 0;
    ptr->readonly = 0;
    ptr->next = (struct symrec *)sym_table;
    sym_table = ptr;
    return ptr;
}

symrec *
getsym(const char *sym_name)
{
    symrec *ptr;
    for (ptr = sym_table; ptr != (symrec *)0; ptr = (symrec *)ptr->next)
        if (strcmp(ptr->name, sym_name) == 0)
            return ptr;
    return 0;
}

/* --- Funciones de inicialización --- */

/*Struc para las funciones*/
struct func_init
{
    const char *fname;
    double (*fnct)();
};

/* Lista de funciones */
struct func_init arith_fncts[] =
{
    {"sin",  sin},
    {"cos",  cos},
    {"atan", atan},
    {"ln",   log},
    {"exp",  exp},
    {"sqrt", sqrt},
    {0, 0}
};


/*Struct para las consantes*/
struct const_init
{
    const char *cname;
    double val;
};

/*Lista de constantes*/
struct const_init arith_consts[] =
{
    {"PI", M_PI},
    {"E",  M_E},
    {0, 0}
};


/* Inicializar la tabla de símbolos. Carga las funciones y las constantes*/
void
init_table(void)
{
    int i;
    symrec *ptr;

    /* Funciones matemáticas */
    for (i = 0; arith_fncts[i].fname != 0; i++)
    {
        ptr = putsym(arith_fncts[i].fname, FNCT);
        ptr->value.fnctptr = arith_fncts[i].fnct;
        ptr->initialized = 1;
    }

    /* Constantes matemáticas */
    for (i = 0; arith_consts[i].cname != 0; i++)
    {
        ptr = putsym(arith_consts[i].cname, VAR);
        ptr->value.var = arith_consts[i].val;
        ptr->initialized = 1;
        ptr->readonly = 1;
    }
}

