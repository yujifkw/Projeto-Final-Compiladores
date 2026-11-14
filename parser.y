%{
/*
 * parser.y - Analisador sintático e construção da AST da linguagem C- (Bison)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ast.h"

int yylex(void);
void yyerror(const char *msg);

extern FILE *yyin;
extern char txt_ultimo_token[];

int erros_sintaticos = 0;
NoAST *raiz_ast = NULL;
%}

%code requires {
    #include "ast.h"
}

%locations              // informa a linha onde ocorreu o evento/erro
%define parse.error verbose // detalha melhor qual tipo de erro ocorreu

%union {
    int ival;
    char *sval;
    NoAST *no;
    TipoDado tipo;
}

%token <sval> ID "identificador"
%token <ival> NUM "numero"
%token TOK_IF "if" TOK_ELSE "else" TOK_WHILE "while" TOK_RETURN "return" TOK_INT "int" TOK_VOID "void"
%token MAIS "+" MENOS "-" MULT "*" DIV "/"
%token LT "<" LE "<=" GT ">" GE ">=" EQ "==" NE "!=" ASSIGN "="
%token SEMI ";" COMMA "," LPAREN "(" RPAREN ")"
%token LBRACKET "[" RBRACKET "]" LBRACE "{" RBRACE "}"

%right IF_SEM_ELSE  // regra fraca, define comportamento para quando um if não tem else(segue normal)
%right TOK_ELSE     // regra forte, faz o else se associar ao if mais próximo

/* No C- (Apêndice A.2 do Louden), operadores relacionais não associam */
%nonassoc LT LE GT GE EQ NE
%left MAIS MENOS
%left MULT DIV

%type <no> programa lista_declaracoes declaracao declaracao_var declaracao_fun
%type <no> parametros lista_parametros parametro
%type <no> bloco declaracoes_locais lista_comandos
%type <no> comando comando_expressao comando_selecao comando_iteracao comando_retorno
%type <no> expressao variavel expressao_simples fator chamada argumentos lista_argumentos
%type <tipo> especificador_tipo

%%

// Programa completo: uma ou mais declarações.
programa
    : lista_declaracoes
        {
            raiz_ast = $1;
            $$ = $1;
        }
    ;

// Sequência de declarações globais.
lista_declaracoes
    : lista_declaracoes declaracao
        {
            $$ = adicionar_irmao($1, $2);
        }
    | declaracao
        {
            $$ = $1;
        }
    ;

// Uma declaração global: variável ou função.
declaracao
    : declaracao_var
        { $$ = $1; }
    | declaracao_fun
        { $$ = $1; }
    ;

// Variável (int x;), vetor (int v[10];) ou declaração com erro, recuperada no ";".
declaracao_var
    : especificador_tipo ID SEMI
        {
            NoAST *no = criar_no(DECL_VAR, @2.first_line);
            no->tipo_dado = $1;
            no->nome = $2;
            $$ = no;
        }
    | especificador_tipo ID LBRACKET NUM RBRACKET SEMI
        {
            NoAST *no = criar_no(DECL_VETOR, @2.first_line);
            no->tipo_dado = $1;
            no->nome = $2;
            no->val = $4;
            $$ = no;
        }
    | especificador_tipo error SEMI
        {
            yyerrok;
            $$ = NULL;
        }
    ;

// Tipo de dado: int ou void.
especificador_tipo
    : TOK_INT   { $$ = INT; }
    | TOK_VOID  { $$ = VOID; }
    ;

// Função: tipo nome(parâmetros) { corpo }.
declaracao_fun
    : especificador_tipo ID LPAREN parametros RPAREN bloco
        {
            NoAST *no = criar_no(DECL_FUN, @2.first_line);
            no->tipo_dado = $1;
            no->nome = $2;
            no->filho[0] = $4;
            no->filho[1] = $6;
            $$ = no;
        }
    ;

// Lista de parâmetros ou apenas void.
parametros
    : lista_parametros
        { $$ = $1; }
    | TOK_VOID
        { $$ = NULL; }
    ;

// Parâmetros separados por vírgula.
lista_parametros
    : lista_parametros COMMA parametro
        { $$ = adicionar_irmao($1, $3); }
    | parametro
        { $$ = $1; }
    ;

// Um parâmetro: int a ou vetor int a[].
parametro
    : especificador_tipo ID
        {
            NoAST *no = criar_no(PARAM_VAR, @2.first_line);
            no->tipo_dado = $1;
            no->nome = $2;
            $$ = no;
        }
    | especificador_tipo ID LBRACKET RBRACKET
        {
            NoAST *no = criar_no(PARAM_VETOR, @2.first_line);
            no->tipo_dado = $1;
            no->nome = $2;
            $$ = no;
        }
    ;

// Bloco { }: declarações locais primeiro, depois os comandos.
bloco
    : LBRACE declaracoes_locais lista_comandos RBRACE
        {
            NoAST *no = criar_no(BLOCO, @1.first_line);
            no->filho[0] = $2;
            no->filho[1] = $3;
            $$ = no;
        }
    ;

// Zero ou mais declarações de variável no início do bloco.
declaracoes_locais
    : declaracoes_locais declaracao_var
        { $$ = adicionar_irmao($1, $2); }
    | /* vazio */
        { $$ = NULL; }
    ;

// Zero ou mais comandos dentro do bloco.
lista_comandos
    : lista_comandos comando
        { $$ = adicionar_irmao($1, $2); }
    | /* vazio */
        { $$ = NULL; }
    ;

// Qualquer comando; "error ;" recupera o parser depois de um erro sintático.
comando
    : comando_expressao { $$ = $1; }
    | bloco             { $$ = $1; }
    | comando_selecao   { $$ = $1; }
    | comando_iteracao  { $$ = $1; }
    | comando_retorno   { $$ = $1; }
    | error SEMI        { yyerrok; $$ = NULL; }
    ;

// Expressão terminada em ";" ou apenas ";" (comando vazio).
comando_expressao
    : expressao SEMI    { $$ = $1; }
    | SEMI              { $$ = NULL; }
    ;

// if com ou sem else; o else casa com o if mais próximo.
comando_selecao
    : TOK_IF LPAREN expressao RPAREN comando %prec IF_SEM_ELSE
        {
            NoAST *no = criar_no(IF, @1.first_line);
            no->filho[0] = $3;
            no->filho[1] = $5;
            $$ = no;
        }
    | TOK_IF LPAREN expressao RPAREN comando TOK_ELSE comando
        {
            NoAST *no = criar_no(IF, @1.first_line);
            no->filho[0] = $3;
            no->filho[1] = $5;
            no->filho[2] = $7;
            $$ = no;
        }
    ;

// Laço while.
comando_iteracao
    : TOK_WHILE LPAREN expressao RPAREN comando
        {
            NoAST *no = criar_no(WHILE, @1.first_line);
            no->filho[0] = $3;
            no->filho[1] = $5;
            $$ = no;
        }
    ;

// return com ou sem valor.
comando_retorno
    : TOK_RETURN SEMI
        {
            NoAST *no = criar_no(RETURN, @1.first_line);
            $$ = no;
        }
    | TOK_RETURN expressao SEMI
        {
            NoAST *no = criar_no(RETURN, @1.first_line);
            no->filho[0] = $2;
            $$ = no;
        }
    ;

// Atribuição (variavel = expressao) ou expressão simples.
expressao
    : variavel ASSIGN expressao
        {
            NoAST *no = criar_no(ATRIB, @2.first_line);
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples
        { $$ = $1; }
    ;

// Variável (x) ou posição de vetor (x[i]).
variavel
    : ID
        {
            NoAST *no = criar_no(VAR, @1.first_line);
            no->nome = $1;
            $$ = no;
        }
    | ID LBRACKET expressao RBRACKET
        {
            NoAST *no = criar_no(VETOR, @1.first_line);
            no->nome = $1;
            no->filho[0] = $3;
            $$ = no;
        }
    ;

// Operações binárias; a precedência e associatividade vêm das declarações acima.
expressao_simples
    : expressao_simples LE expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "<=";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples LT expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "<";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples GT expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = ">";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples GE expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = ">=";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples EQ expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "==";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples NE expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "!=";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples MAIS expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "+";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples MENOS expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "-";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples MULT expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "*";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | expressao_simples DIV expressao_simples
        {
            NoAST *no = criar_no(OP, @2.first_line);
            no->op = "/";
            no->filho[0] = $1;
            no->filho[1] = $3;
            $$ = no;
        }
    | fator
        { $$ = $1; }
    ;

// Operando: expressão entre parênteses, variável, chamada ou número.
fator
    : LPAREN expressao RPAREN
        { $$ = $2; }
    | variavel
        { $$ = $1; }
    | chamada
        { $$ = $1; }
    | NUM
        {
            NoAST *no = criar_no(CONST, @1.first_line);
            no->val = $1;
            no->tipo_dado = INT;
            $$ = no;
        }
    ;

// Chamada de função: nome(argumentos).
chamada
    : ID LPAREN argumentos RPAREN
        {
            NoAST *no = criar_no(CHAMADA, @1.first_line);
            no->nome = $1;
            no->filho[0] = $3;
            $$ = no;
        }
    ;

// Argumentos da chamada, ou nenhum.
argumentos
    : lista_argumentos  { $$ = $1; }
    | /* vazio */       { $$ = NULL; }
    ;

// Expressões separadas por vírgula.
lista_argumentos
    : lista_argumentos COMMA expressao
        { $$ = adicionar_irmao($1, $3); }
    | expressao
        { $$ = $1; }
    ;

%%

/*
 * Quando há um erro sintático, o Bison monta uma mensagem em inglês, por exemplo:
 * syntax error, unexpected identificador, expecting ";" or "(" or "["
 * Essa função pega só a parte depois de expecting e a transforma em ";" ou "(" ou "["
 * Se o Bison não informar os tokens esperados, usa um texto genérico.
 */
static void format_expected(const char *msg, char *out, size_t size)
{
    const char *p = strstr(msg, "expecting ");
    char item[64];
    size_t used = 0;

    out[0] = '\0';
    if (p == NULL) {
        snprintf(out, size, "construcao valida");
        return;
    }
    p += strlen("expecting ");

    while (*p != '\0') {
        const char *end = strstr(p, " or ");
        size_t len = end ? (size_t)(end - p) : strlen(p);
        int n;

        if (len >= sizeof item)
            len = sizeof item - 1;

        memcpy(item, p, len);
        item[len] = '\0';

        if (len >= 2 && item[0] == '"' && item[len - 1] == '"') {
            item[len - 1] = '\0';
            memmove(item, item + 1, len - 1);
        }

        n = snprintf(out + used, size - used, "%s%s", used ? "\" ou \"" : "", item);
        if (n < 0 || (size_t)n >= size - used)
            break;
        used += (size_t)n;

        if (end == NULL)
            break;
        p = end + strlen(" or ");
    }
}

/*
 * Chamada pelo Bison a cada erro sintático. O token inesperado é o último
 * lexema lido pelo scanner e a linha vem da localização do lookahead.
 */
void yyerror(const char *msg)
{
    char expected[256];

    format_expected(msg, expected, sizeof expected);

    erros_sintaticos++;

    printf("ERRO SINTATICO: token inesperado \"%s\", esperado \"%s\" - LINHA: %d\n",
           txt_ultimo_token,
           expected,
           yylloc.first_line);
}

int main(int argc, char **argv)
{
    int resultado;

    if (argc != 2) {
        fprintf(stderr, "Uso: %s arquivo.cm\n", argv[0]);
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        fprintf(stderr, "Nao foi possivel abrir \"%s\".\n", argv[1]);
        return 1;
    }

    resultado = yyparse();
    fclose(yyin);

    if (resultado != 0 || erros_sintaticos > 0) {
        printf("\nCompilacao interrompida: %d erro(s) sintatico(s).\n", erros_sintaticos);
        liberar_ast(raiz_ast);
        return 1;
    }

    printf("\n================================================================================\n");
    printf("                     ARVORE SINTATICA ABSTRATA (AST)\n");
    printf("================================================================================\n");
    imprimir_ast(raiz_ast, 0);
    printf("================================================================================\n");

    if (salvar_ast_dot(raiz_ast, "ast.dot") == 0) {
        printf("\n[Info] Arquivo Graphviz gerado em \"ast.dot\".\n");
    }

    liberar_ast(raiz_ast);
    return 0;
}
