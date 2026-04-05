%{
#include "calc.h"
#include "calc.tab.h"
#include <ctype.h>
#include <stdlib.h>
#include <string.h>

void load_script(const char *filename);

static int script_load_depth = 0;

#define MAX_SCRIPT_BUFFERS 64 // Evita que se carguen archivos de forma recursiva 
static YY_BUFFER_STATE script_buffers[MAX_SCRIPT_BUFFERS]; // Buffer para las diferentes entradas
static FILE *script_files[MAX_SCRIPT_BUFFERS]; // Array de los archivos que abrimos
static int script_stack_top = 0; // Tope del stack de archivos abiertos
%}

%option noinput nounput

%%

\"[^\"]*\"          {
                        yylval.str = strdup(yytext + 1);
                        yylval.str[strlen(yylval.str) - 1] = '\0';
                        return STR;
                    }

"workspace"         { return CMD_WORKSPACE; }
"clean"             { return CMD_CLEAN; }
"clear"             { return CMD_CLEAR; }
"quit"|"QUIT"|"exit"|EXIT  { return CMD_QUIT; }
"echo"|"ECHO"       { return CMD_ECHO; }
"on"|"ON"           { return CMD_ON; }
"off"|"OFF"         { return CMD_OFF; }
"help"|"HELP"       { return CMD_HELP; }
"load"|"LOAD"       { return CMD_LOAD; }
"?"                 { return '?'; }

[0-9]+(\.[0-9]+)?   {
                        yylval.val = atof(yytext);
                        return NUM;
                    }

[a-zA-Z][a-zA-Z0-9]* {
                        symrec *s;
                        s = getsym(yytext);
                        if (s == 0)
                            s = putsym(yytext, VAR);
                        yylval.tptr = s;
                        return s->type;
                    }

[ \t]               { /* ignorar espacios en blanco */ }
\n                  { return '\n'; }
.                   { return yytext[0]; }

<<EOF>>             {
                        if (script_stack_top > 0) {
                            FILE *finished_file = script_files[script_stack_top - 1];

                            yypop_buffer_state();

                            if (finished_file != NULL && finished_file != stdin) {
                                fclose(finished_file);
                            }

                            script_stack_top--;
                            if (script_load_depth > 0) {
                                script_load_depth--;
                            }

                            return '\n';
                        }

                        yyterminate();
                    }

%%

int yywrap(void)
{
    return 1;
}

void cleanup_lexer_resources(void)
{
    while (script_stack_top > 0)
    {
        FILE *pending_file = script_files[script_stack_top - 1];

        script_files[script_stack_top - 1] = NULL;
        script_buffers[script_stack_top - 1] = NULL;
        script_stack_top--;

        if (pending_file != NULL && pending_file != stdin)
        {
            fclose(pending_file);
        }
    }

    script_load_depth = 0;
    yylex_destroy();
}

void load_script(const char *filename) {
    FILE *f = fopen(filename, "r");
    YY_BUFFER_STATE buffer;

    if (!f) {
        fprintf(stderr, "Error: no se pudo abrir, o formato no soportado en fichero '%s'\n", filename);
        return;
    }

    buffer = yy_create_buffer(f, YY_BUF_SIZE);
    if (buffer == NULL) {
        fclose(f);
        fprintf(stderr, "Error: no se pudo crear el buffer para '%s'\n", filename);
        return;
    }

    if (script_stack_top >= MAX_SCRIPT_BUFFERS) {
        yy_delete_buffer(buffer);
        fclose(f);
        fprintf(stderr, "Error: demasiados scripts anidados (max %d)\n", MAX_SCRIPT_BUFFERS);
        return;
    }

    script_buffers[script_stack_top] = buffer;
    script_files[script_stack_top] = f;
    script_stack_top++;
    script_load_depth++;
    yypush_buffer_state(buffer);
}

int is_loading_script(void)
{
    return script_load_depth > 0;
}

/* Funcionamiento buffers flex apuntes

En flex cada fuente de entrada tiene su propio "buffer" (tipo YY_BUFFER_STATE)
que almacena el contenido, punteros y el FILE* asociado.
yy_create_buffer(f, size) crea el buffer asociado al FILE* f.
yypush_buffer_state(buf) apila ese buffer y cambia la entrada activa a ese buffer;
las siguientes lecturas vienen de ahí.
yypop_buffer_state() desapila el buffer activo y restaura el anterior.
IMPORTANTE: yypop_buffer_state() no cierra automáticamente el FILE* ni borra el buffer con yy_delete_buffer(); si tú creaste el FILE* con fopen debes cerrarlo (fclose) y eliminar el buffer (yy_delete_buffer) cuando ya no lo necesites, o habrá fugas de descriptor/memoria.
El token <<EOF>> se ejecuta cuando se alcanza EOF del buffer activo; allí es el sitio apropiado para limpiar (cerrar fichero / borrar buffer / devolver un '\n' virtual si quieres).

*/