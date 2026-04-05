#include "calc.h"
#include "calc.tab.h"
#include <stdio.h>
#include <stdlib.h>

int echo_mode = 1;

extern int yyparse(void);
extern void init_table(void);

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

void print_help(const char *topic) {
    if (topic == NULL) {
        printf("--- Ayuda del intérprete ---\n");
        printf("  load(\"file.calc\") : carga y ejecuta un script de expresiones.\n");
        printf("  help o ?            : muestra esta ayuda. Usa '? <func>' para más detalles.\n");
        printf("  workspace           : muestra las variables definidas en la sesión.\n");
        printf("  clean               : elimina todas las variables.\n");
        printf("  clean <var>         : elimina una variable específica.\n");
        printf("  clear               : limpia la pantalla.\n");
        printf("  echo on / echo off  : activa o desactiva la impresión y obligatoriedad de ';'.\n");
        printf("  quit                : sale del intérprete al shell de linux.\n");
    } else {
        printf("Ayuda específica para '%s':\n", topic);
        if (strcmp(topic, "sin") == 0) printf("  sin(x): calcula el seno de x en radianes.\n");
        else if (strcmp(topic, "cos") == 0) printf("  cos(x): calcula el coseno de x en radianes.\n");
        else if (strcmp(topic, "atan") == 0) printf("  atan(x): calcula la arcotangente de x.\n");
        else if (strcmp(topic, "ln") == 0) printf("  ln(x): calcula el logaritmo neperiano de x.\n");
        else if (strcmp(topic, "exp") == 0) printf("  exp(x): calcula e elevado a la x.\n");
        else if (strcmp(topic, "sqrt") == 0) printf("  sqrt(x): calcula la raíz cuadrada de x.\n");
        else printf("  No hay documentación específica para '%s'.\n", topic);
    }
}

void print_workspace(void) {
    symrec *ptr;
    int count = 0;
    printf("--- Workspace ---\n");
    for (ptr = sym_table; ptr != NULL; ptr = ptr->next) {
        if (ptr->type == VAR && !ptr->readonly && ptr->initialized) {
            count++;
            printf("  %s = %.10g\n", ptr->name, ptr->value.var);
        }
    }
    if (count == 0) printf("  (vacío)\n");
    printf("-----------------\n");
}

void clean_workspace(const char *name) {
    symrec *ptr, *prev = NULL;
    if (name == NULL) {
        ptr = sym_table;
        while (ptr != NULL) {
            if (ptr->type == VAR && !ptr->readonly) {
                symrec *to_free = ptr;
                if (prev == NULL) sym_table = ptr->next;
                else prev->next = ptr->next;
                ptr = ptr->next;
                free(to_free->name);
                free(to_free);
            } else {
                prev = ptr;
                ptr = ptr->next;
            }
        }
        printf("Workspace limpiado con éxito.\n");
    } else {
        for (ptr = sym_table; ptr != NULL; ptr = ptr->next) {
            if (strcmp(ptr->name, name) == 0) {
                if (ptr->readonly) {
                    printf("Error: la constante o valor del sistema '%s' no se puede eliminar.\n", name);
                    return;
                }
                if (prev == NULL) sym_table = ptr->next;
                else prev->next = ptr->next;
                free(ptr->name);
                free(ptr);
                printf("Variable '%s' eliminada.\n", name);
                return;
            }
            prev = ptr;
        }
        printf("Error: Variable '%s' no encontrada.\n", name);
    }
}

void free_all_memory(void) {
    symrec *ptr = sym_table;
    while (ptr != NULL) {
        symrec *to_free = ptr;
        ptr = ptr->next;
        free(to_free->name);
        free(to_free);
    }
    sym_table = NULL;
}

int main(void)
{
    init_table();
    printf("Calculadora multi-función (mfcalc)\n");
    printf("Funciones disponibles: sin, cos, atan, ln, exp, sqrt\n");
    printf("Pulsa '?' para buscar ayuda.\n");
    
    if (echo_mode) printf("\nIntroduce expresiones (Ctrl+D para salir):\n> ");
    yyparse();
    printf("\nSaliendo del intérprete...\n");
    cleanup_lexer_resources();
    free_all_memory();
    return 0;
}
