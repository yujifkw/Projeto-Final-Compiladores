/*
 * symtab.h - Tabela de Símbolos com pilha de escopos para a linguagem C-
 *
 * Baseada na estrutura de pilha de escopos (Escopo / topo_escopo) apresentada
 * em aula, mantendo também o histórico completo de símbolos declarados para
 * exibição da Tabela de Símbolos ao final da compilação.
 */
#ifndef SYMTAB_H
#define SYMTAB_H

#include "ast.h"

/* Categoria do símbolo na Tabela de Símbolos */
typedef enum {
    VARIAVEL,       /* Variável escalar: int x; */
    VAR_VETOR,      /* Variável vetor: int v[10]; (evita conflito com VETOR de ast.h) */
    PARAMETRO,      /* Parâmetro escalar: int a */
    PAR_VETOR,      /* Parâmetro vetor: int a[] (evita conflito com PARAM_VETOR de ast.h) */
    FUNCAO          /* Função: int f(...) / void f(...) */
} CategoriaSimbolo;

/* Lista encadeada de tipos dos parâmetros de uma função (para checar chamadas) */
typedef struct ParamInfo {
    TipoDado tipo;              /* INT ou INT_VETOR */
    struct ParamInfo *prox;
} ParamInfo;

/* Entrada da Tabela de Símbolos */
typedef struct Simbolo {
    char *nome;                 /* Nome do identificador */
    CategoriaSimbolo categoria; /* Variável, Vetor, Parâmetro ou Função */
    TipoDado tipo;              /* Tipo base: INT ou VOID */
    int tamanho;                /* Tamanho do vetor (se CAT_VETOR), 0 caso contrário */
    char *escopo_nome;          /* Nome do escopo onde foi declarado ("global", "main", etc.) */
    int nivel_escopo;           /* Profundidade do escopo (0 = global, 1 = função, 2+ = bloco) */
    int linha;                  /* Linha da declaração no código-fonte */
    int num_params;             /* Número de parâmetros (se CAT_FUNCAO) */
    ParamInfo *params;          /* Lista dos parâmetros da função (se CAT_FUNCAO) */
    struct Simbolo *prox;       /* Próximo símbolo na lista do escopo ativo */
    struct Simbolo *prox_hist;  /* Próximo símbolo na lista histórica completa */
} Simbolo;

/* Estrutura de um escopo na pilha de escopos ativos */
typedef struct Escopo {
    char *nome;                 /* Nome do escopo (ex: "global", "main", "main.bloco1") */
    int nivel;                  /* Nível de aninhamento */
    Simbolo *simbolos;          /* Lista encadeada de símbolos visíveis neste escopo */
    struct Escopo *prox;        /* Ponteiro para o escopo imediatamente externo (pai) */
} Escopo;

/* Inicializa a tabela de símbolos, abre o escopo "global" e registra input() e output() */
void init_symtab(void);

/* Empilha um novo escopo ativo (enter_scope) */
void enter_scope(const char *nome_escopo);

/* Desempilha o escopo ativo atual (leave_scope) sem apagar os símbolos do histórico */
void leave_scope(void);

/* Procura um símbolo APENAS no escopo atual (para detectar declaração duplicada) */
Simbolo *find_sym_current(const char *nome);

/* Procura um símbolo em todos os escopos ativos, do mais interno até o global */
Simbolo *find_sym(const char *nome);

/* Procura um símbolo especificamente no escopo global */
Simbolo *find_sym_global(const char *nome);

/* Insere um novo símbolo no escopo atual e no histórico da tabela */
Simbolo *declare_sym(const char *nome, CategoriaSimbolo categoria, TipoDado tipo, int tamanho, int linha);

/* Registra o tipo de um parâmetro na entrada de uma função na Tabela de Símbolos */
void adicionar_param_simbolo(Simbolo *func, TipoDado tipo_param);

/* Percorre a AST registrando todas as declarações e escopos na Tabela de Símbolos */
void popular_tabela_simbolos(NoAST *raiz);

/* Imprime a Tabela de Símbolos completa formatada */
void imprimir_tabela_simbolos(void);

/* Libera toda a memória da Tabela de Símbolos */
void liberar_tabela_simbolos(void);

#endif /* SYMTAB_H */
