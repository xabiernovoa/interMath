#ifndef CALC_H
#define CALC_H

#include <stdlib.h>
#include <string.h>

/* Tipo de datos para enlaces en la cadena de símbolos. */
struct symrec
{
    char *name;      /* nombre del símbolo                 */
    int type;        /* tipo del símbolo: bien VAR o FNCT  */
    union {
        double var;           /* valor de una VAR   */
        double (*fnctptr)();  /* valor de una FNCT  */
    } value;
    int initialized;             /* 1 si la variable ha sido inicializada */
    int readonly;                /* 1 si es constante (no se puede modificar) */
    struct symrec *next;     /* campo de enlace */
};

typedef struct symrec symrec;

/* La tabla de símbolos: una cadena de 'struct symrec'. */
extern symrec *sym_table;
extern int echo_mode;

symrec *putsym(const char *sym_name, int sym_type);
symrec *getsym(const char *sym_name);

/* Comandos del sistema a definir en inter.c y lexico.l */
void print_workspace(void);
void clean_workspace(const char *name);
void print_help(const char *topic);
void load_script(const char *filename);
void free_all_memory(void);
int is_loading_script(void);
void cleanup_lexer_resources(void);

#endif /* CALC_H */
