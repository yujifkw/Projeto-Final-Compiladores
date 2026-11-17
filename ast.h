/*
 * ast.h - Estruturas e funções da Árvore Sintática Abstrata (AST) para C-
 */
#ifndef AST_H
#define AST_H

#include <stdio.h>

/* Tipos de nós da AST (Declarações, Comandos e Expressões) */
typedef enum {
    DECL_VAR,     /* Declaração de variável escalar: int x; */
    DECL_VETOR,   /* Declaração de vetor: int v[10]; */
    DECL_FUN,     /* Declaração de função: tipo id(params) { ... } */
    PARAM_VAR,    /* Parâmetro escalar: int a */
    PARAM_VETOR,  /* Parâmetro vetor: int a[] */
    BLOCO,        /* Bloco composto: { declaracoes_locais lista_comandos } */
    IF,           /* Comando condicional: if (cond) entao [else senao] */
    WHILE,        /* Comando de repetição: while (cond) corpo */
    RETURN,       /* Comando de retorno: return [expr]; */
    ATRIB,        /* Expressão de atribuição: variavel = expressao */
    OP,           /* Expressão binária: esq op dir */
    VAR,          /* Uso de variável escalar (ou nome de vetor sem índice): id */
    VETOR,        /* Acesso a posição de vetor: id[expr] */
    CHAMADA,      /* Chamada de função: id(argumentos) */
    CONST         /* Constante inteira: NUM */
} TipoNo;

/* Tipos de dados da linguagem C- */
typedef enum {
    VOID,
    INT,
    INT_VETOR,
    ERRO
} TipoDado;

/* Estrutura de um nó da AST */
typedef struct NoAST {
    TipoNo tipo_no;             /* Categoria do nó na AST */
    TipoDado tipo_dado;         /* Tipo declarado ou inferido na análise semântica */
    int linha;                  /* Linha do código-fonte onde o nó aparece */
    char *nome;                 /* Nome do identificador (ID), se aplicável */
    int val;                    /* Valor numérico (constante NUM ou tamanho de vetor) */
    const char *op;             /* Operador binário ("+", "-", "*", "<=", etc.) */
    int escopo_criado_pela_fun; /* Flag interna: 1 se o bloco é o corpo principal de uma função */
    struct NoAST *filho[3];     /* Ponteiros para até 3 subárvores filhas */
    struct NoAST *prox;         /* Ponteiro para o próximo nó irmão (listas) */
} NoAST;

/* Cria e inicializa um novo nó da AST */
NoAST *criar_no(TipoNo tipo_no, int linha);

/* Concatena um nó ao final de uma lista de irmãos (via ponteiro prox) */
NoAST *adicionar_irmao(NoAST *lista, NoAST *novo);

/* Retorna o nome textual de um TipoDado ("int", "void", "int[]", "erro") */
const char *nome_tipo_dado(TipoDado tipo);

/* Imprime a AST em formato textual indentado na saída padrão */
void imprimir_ast(NoAST *raiz, int nivel);

/* Exporta a AST no formato Graphviz (.dot) */
int salvar_ast_dot(NoAST *raiz, const char *caminho_arquivo);

/* Libera toda a memória alocada pela AST */
void liberar_ast(NoAST *raiz);

#endif /* AST_H */
