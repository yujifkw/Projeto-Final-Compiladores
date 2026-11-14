%{
/*
 * scanner.l - Analisador léxico da linguagem C- (Flex).
 *
 * Qualquer erro léxico imprime "ERRO LEXICO: "lexema" - LINHA: X" e encerra a
 * compilação.
 */
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ast.h"
#include "parser.tab.h"

char txt_ultimo_token[64] = "";  // Texto do último token lido; usado pelo parser nas mensagens de erro.

static int comment_line = 0;

static char *duplicar_lexema(const char *s)
{
    size_t n = strlen(s) + 1;
    char *copia = (char *)malloc(n);
    if (copia == NULL) {
        fprintf(stderr, "Erro fatal: falta de memoria no scanner.\n");
        exit(EXIT_FAILURE);
    }
    memcpy(copia, s, n);
    return copia;
}

static void erro_lexico(const char *lexema, int linha)
{
    printf("ERRO LEXICO: \"%s\" - LINHA: %d\n", lexema, linha);
    fflush(stdout);
    exit(EXIT_FAILURE);
}

/* Antes de cada ação: registra linha do token e o lexema atual para fazer as mensagens de erro. */
#define YY_USER_ACTION                                                              \
    yylloc.first_line = yylloc.last_line = yylineno;                                \
    if (YY_START == INITIAL &&                                                      \
        yytext[0] != ' ' && yytext[0] != '\t' &&                                    \
        yytext[0] != '\r' && yytext[0] != '\n' &&                                   \
        strncmp(yytext, "/*", 2) != 0) {                                            \
        strncpy(txt_ultimo_token, yytext, sizeof(txt_ultimo_token) - 1);            \
        txt_ultimo_token[sizeof(txt_ultimo_token) - 1] = '\0';                      \
    }
%}

/* yylineno guarda o numero da linha de codigo que esta sendo analisada. */
%option noyywrap yylineno nounput noinput

/* %x (exclusivo): enquanto o scanner está nesse estado, só valem as regras marcadas com ele. Todas as outras ficam desligadas.
   Usamos %x porque dentro de um comentário nada deve ser reconhecido. Um if ou um + escrito dentro do comentário não pode virar token.
   Ao ler "barra asterisco" muda para o estado COMMENT que consome qualquer coisa que não seja "asterisco barra" sem gerar tokens. */
%x COMMENT

%%

"/*"                { comment_line = yylineno; BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); /* começa o estado INITIAL, que é o padrão e usa as regras abaixo */ }
<COMMENT>[^*]+      { /* conteúdo do comentário */ }
<COMMENT>"*"        { /* asterisco isolado */ }
<COMMENT><<EOF>>    {
                        yylloc.first_line = comment_line;
                        erro_lexico("/*", comment_line);
                    }

"else"              { return TOK_ELSE; }
"if"                { return TOK_IF; }
"int"               { return TOK_INT; }
"return"            { return TOK_RETURN; }
"void"              { return TOK_VOID; }
"while"             { return TOK_WHILE; }

"+"                 { return MAIS; }
"-"                 { return MENOS; }
"*"                 { return MULT; }
"/"                 { return DIV; }
"<="                { return LE; }
"<"                 { return LT; }
">="                { return GE; }
">"                 { return GT; }
"=="                { return EQ; }
"!="                { return NE; }
"="                 { return ASSIGN; }
";"                 { return SEMI; }
","                 { return COMMA; }
"("                 { return LPAREN; }
")"                 { return RPAREN; }
"["                 { return LBRACKET; }
"]"                 { return RBRACKET; }
"{"                 { return LBRACE; }
"}"                 { return RBRACE; }

[0-9]+              {
                        long valor;
                        errno = 0;                                 //errno: variável global onde funções da biblioteca registram um erro. Não zera sozinha, por isso errno = 0 antes de chamar strtol.
                        valor = strtol(yytext, NULL, 10);          // strtol(const char *str, char **endptr, int base); transforma str pra int, endptr não importa pois o final do numero é o final da expressao
                        if (errno == ERANGE || valor > INT_MAX)    // evita que o numero seja maior que o espaço de um int, ERANGE é o valor que o errno.h poe no errno caso acabe o espaço
                            erro_lexico(yytext, yylineno);
                        yylval.ival = (int)valor;
                        return NUM;
                    }

[a-zA-Z]+           {
                        yylval.sval = duplicar_lexema(yytext);
                        return ID;
                    }

[a-zA-Z0-9_]*[0-9_][a-zA-Z0-9_]*  { erro_lexico(yytext, yylineno); /* identificador não pode ter numeros */ }

[ \t\r\n]+          { /* espaços em branco */ }

<<EOF>>             {
                        strcpy(txt_ultimo_token, "EOF");
                        yylloc.first_line = yylloc.last_line = yylineno;
                        yyterminate(); // É um macro do Flex que encerra a leitura do arquivo: o scanner devolve 0 ao parser, e o Bison entende esse 0 como “fim da entrada” (o token $end).
                    }

.                   { erro_lexico(yytext, yylineno); /* caso nao reconheça nada da erro */ }

%%
