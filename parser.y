%{
/*
 * parser.y - Analisador sintático da linguagem C- (Bison)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *msg);

extern FILE *yyin;
extern char txt_ultimo_token[];

int erros_sintaticos = 0;
%}

%locations // informa a linha onde ocorreu o evento/erro
%error-verbose // detalha melhor qual tipo de erro ocorreu

%token ID "identificador"
%token NUM "numero"
%token IF "if" ELSE "else" WHILE "while" RETURN "return" INT "int" VOID "void"
%token MAIS "+" MENOS "-" MULT "*" DIV "/"
%token LT "<" LE "<=" GT ">" GE ">=" EQ "==" NE "!=" ASSIGN "="
%token SEMI ";" COMMA "," LPAREN "(" RPAREN ")"
%token LBRACKET "[" RBRACKET "]" LBRACE "{" RBRACE "}"

%right IF_SEM_ELSE  // regra fraca, define comportamento para quando um if não tem else(segue normal), evitando uns warnings que ficam aparecendo, basicamente nn muda nada
%right ELSE        // regra forte, como foi definida depois ela sobressai a primeira, fazendo os elses se linkarem com o if mais próximo, O %right poderia ser %left, não tem como ter dois if elses na mesma linha, mas o bison precisa do %right pra aceitar por uma regra.

%left LT LE GT GE EQ NE
%left MAIS MENOS
%left MULT DIV


%%

// Programa completo: uma ou mais declarações.  
programa
    : lista_declaracoes
    ;

// Sequência de declarações globais.  
lista_declaracoes
    : lista_declaracoes declaracao
    | declaracao
    ;

// Uma declaração global: variável ou função. 
declaracao
    : declaracao_var
    | declaracao_fun
    ;

// Variável (int x;), vetor (int v[10];) ou declaração com erro, recuperada no ";".  
declaracao_var
    : especificador_tipo ID SEMI
    | especificador_tipo ID LBRACKET NUM RBRACKET SEMI
    | especificador_tipo error SEMI         { yyerrok; }
    ;

// Tipo de dado: int ou void. 
especificador_tipo
    : INT
    | VOID
    ;

// Função: tipo nome(parâmetros) { corpo }. 
declaracao_fun
    : especificador_tipo ID LPAREN parametros RPAREN bloco
    ;

// Lista de parâmetros ou apenas void.  
parametros
    : lista_parametros
    | VOID
    ;

// Parâmetros separados por vírgula.  
lista_parametros
    : lista_parametros COMMA parametro
    | parametro
    ;

// Um parâmetro: int a ou vetor int a[]. 
parametro
    : especificador_tipo ID
    | especificador_tipo ID LBRACKET RBRACKET
    ;

// Bloco { }: declarações locais primeiro, depois os comandos. 
bloco
    : LBRACE declaracoes_locais lista_comandos RBRACE
    ;

// Zero ou mais declarações de variável no início do bloco.  
declaracoes_locais
    : declaracoes_locais declaracao_var
    | /* vazio */
    ;

// Zero ou mais comandos dentro do bloco. 
lista_comandos
    : lista_comandos comando
    | /* vazio */
    ;

// Qualquer comando; "error ;" recupera o parser depois de um erro sintático.  
comando
    : comando_expressao
    | bloco
    | comando_selecao
    | comando_iteracao
    | comando_retorno
    | error SEMI                            { yyerrok; }
    ;

// Expressão terminada em ";" ou apenas ";" (comando vazio).  
comando_expressao
    : expressao SEMI
    | SEMI
    ;

// if com ou sem else; o else casa com o if mais próximo.  
comando_selecao
    : IF LPAREN expressao RPAREN comando %prec IF_SEM_ELSE
    | IF LPAREN expressao RPAREN comando ELSE comando
    ;

// Laço while. 
comando_iteracao
    : WHILE LPAREN expressao RPAREN comando
    ;

// return com ou sem valor. 
comando_retorno
    : RETURN SEMI
    | RETURN expressao SEMI
    ;

// Atribuição (variavel = expressao) ou expressão simples. 
expressao
    : variavel ASSIGN expressao
    | expressao_simples
    ;

// Variável (x) ou posição de vetor (x[i]). 
variavel
    : ID
    | ID LBRACKET expressao RBRACKET
    ;

// Operações binárias; a precedência vem dos %left acima. 
expressao_simples
    : expressao_simples LE expressao_simples
    | expressao_simples LT expressao_simples
    | expressao_simples GT expressao_simples
    | expressao_simples GE expressao_simples
    | expressao_simples EQ expressao_simples
    | expressao_simples NE expressao_simples
    | expressao_simples MAIS expressao_simples
    | expressao_simples MENOS expressao_simples
    | expressao_simples MULT expressao_simples
    | expressao_simples DIV expressao_simples
    | fator
    ;

// Operando: expressão entre parênteses, variável, chamada ou número. 
fator
    : LPAREN expressao RPAREN
    | variavel
    | chamada
    | NUM
    ;

// Chamada de função: nome(argumentos). 
chamada
    : ID LPAREN argumentos RPAREN
    ;

// Argumentos da chamada, ou nenhum.  (exemplo soma() ou somaa(1) ou somaaa(1,2))
argumentos
    : lista_argumentos
    | /* vazio */
    ;

// Expressões separadas por vírgula. (exemplo chamar uma função soma: soma(1, 2))
lista_argumentos
    : lista_argumentos COMMA expressao
    | expressao
    ;

%%

/*
 * Quando há um erro sintático, o Bison monta uma mensagem em inglês, por exemplo: syntax error, unexpected identificador, expecting ";" or "(" or "["
 * Essa função pega só a parte depois de expecting e a transforma em ";" ou "(" ou "["
 * Se o Bison não informar os tokens esperados, usa um texto genérico.
 */
static void format_expected(const char *msg, char *out, size_t size)
{
    /* strstr procura um texto dentro de outro e devolve um ponteiro para onde
       ele começa, ou NULL se não achar. Aqui acha o "expecting " na mensagem. */
    const char *p = strstr(msg, "expecting ");
    char item[64];            /* guarda um token esperado de cada vez */

    /* size_t é o tipo do C para tamanhos e contagens (sempre >= 0), o mesmo
       que sizeof e strlen devolvem. "used" conta quantos caracteres já foram
       escritos em "out". */
    size_t used = 0;

    out[0] = '\0';            /* começa com o texto vazio */
    if (p == NULL) {          /* o Bison não listou o que esperava */
        snprintf(out, size, "construcao valida");
        return;
    }
    p += strlen("expecting "); /* pula a palavra e fica no começo da lista */

    while (*p != '\0') {
        /* acha o próximo " or ". Se for o último item, "end" fica NULL */
        const char *end = strstr(p, " or ");

        /* tamanho do item atual: da posição p até end (subtração de
           ponteiros dá o número de caracteres entre eles) ou até o fim */
        size_t len = end ? (size_t)(end - p) : strlen(p);
        int n;

        if (len >= sizeof item)     /* não deixa estourar o vetor item[64] */
            len = sizeof item - 1;

        /* memcpy copia "len" bytes de p para item. Ela NÃO coloca o '\0' no
           fim, por isso a linha seguinte faz isso */
        memcpy(item, p, len);
        item[len] = '\0';

        /* se o item vem entre aspas ("(", por exemplo), tira as aspas */
        if (len >= 2 && item[0] == '"' && item[len - 1] == '"') {
            item[len - 1] = '\0';              /* apaga a aspa do final */
            /* memmove desloca o texto uma posição para a esquerda, o que
               apaga a aspa do começo. É memmove e não memcpy porque origem e
               destino estão no mesmo vetor e se sobrepõem; memcpy não
               garante o resultado nesse caso */
            memmove(item, item + 1, len - 1);
        }

        /* snprintf escreve texto formatado com limite de tamanho.
           - out + used: escreve logo depois do que já foi escrito
           - size - used: espaço que ainda resta (evita estourar "out")
           - o separador só entra a partir do 2º item (used != 0); ele é o
             texto  " ou "  que fecha a aspa, escreve "ou" e abre outra
           Devolve quantos caracteres escreveu, ou um valor negativo se deu
           erro. */
        n = snprintf(out + used, size - used, "%s%s", used ? "\" ou \"" : "", item);
        if (n < 0 || (size_t)n >= size - used)  /* erro, ou não coube tudo */
            break;
        used += (size_t)n;                      /* avança o ponto de escrita */

        if (end == NULL)                        /* era o último item */
            break;
        p = end + strlen(" or ");               /* vai para o próximo item */
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

   // Imprime no formato do trabalho. Cada \" é uma aspa dentro do texto.
    printf("ERRO SINTATICO: token inesperado \"%s\", esperado \"%s\" - LINHA: %d\n",
           txt_ultimo_token,      // 1 %s: o token que causou o erro
           expected,              // 2 %s: o que era esperado 
           yylloc.first_line);    // %d: a linha do erro 
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
        return 1;
    }
    printf("Analise lexica e sintatica concluida sem erros.\n");
    return 0;
}
