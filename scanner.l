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

#include "parser.tab.h"

char txt_ultimo_token[64] = "";  // Texto do último token lido; usado pelo parser nas mensagens de erro. 

static int comment_line = 0;

static void erro_lexico(const char *lexema, int linha)
{
    printf("ERRO LEXICO: \"%s\" - LINHA: %d\n", lexema, linha);
    fflush(stdout);
    exit(EXIT_FAILURE);
}

// Antes de cada ação: registra linha do token e o lexema atual para fazer as mensagens de erro. 
#define YY_USER_ACTION                                                      \
    yylloc.first_line = yylloc.last_line = yylineno;                        \
    strncpy(txt_ultimo_token, yytext, sizeof(txt_ultimo_token) - 1);        \
    txt_ultimo_token[sizeof(txt_ultimo_token) - 1] = '\0';
%}

// yylineno guarda o numero da linha de codigo que esta sendo analisada
%option noyywrap yylineno 


// %x (exclusivo): enquanto o scanner está nesse estado, só valem as regras marcadas com ele. Todas as outras ficam desligadas.
// Usamos %x porque dentro de um comentário nada deve ser reconhecido. Um if ou um + escrito dentro do comentário não pode virar token.
// ao ler "\*" muda para o estado comment que consome qualquer coisa que não seja "*/" sem gerar tokens.
%x COMMENT 

%%

"/*"                { comment_line = yylineno; BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); // começa o estado initial, que é o padrão e usa as regras abaixo }
<COMMENT>[^*]+      { // conteúdo do comentário }
<COMMENT>"*"        { // asterisco isolado  }
<COMMENT><<EOF>>    {
                        yylloc.first_line = comment_line;
                        erro_lexico("/*", comment_line);
                    }

"else"              { return ELSE; }
"if"                { return IF; }
"int"               { return INT; }
"return"            { return RETURN; }
"void"              { return VOID; }
"while"             { return WHILE; }

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
                        return NUM;
                    }

[a-zA-Z]+           { return ID; }

[a-zA-Z0-9_]*[0-9_][a-zA-Z0-9_]*  { erro_lexico(yytext, yylineno); // identificador não pode ter numeros}

[ \t\r\n]+          { /* espaços em branco */ }

<<EOF>>             {
                        strcpy(txt_ultimo_token, "EOF");
                        yylloc.first_line = yylloc.last_line = yylineno;
                        yyterminate(); // É um macro do Flex que encerra a leitura do arquivo: o scanner devolve 0 ao parser, e o Bison entende esse 0 como “fim da entrada” (o token $end).
                    }

.                   { erro_lexico(yytext, yylineno); // caso nao reconheça nada da erro}

%%
