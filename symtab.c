/*
 * symtab.c - Implementação da Tabela de Símbolos com pilha de escopos
 */
#include "symtab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Topo da pilha de escopos ativos (mesmo modelo de seman2.y da aula) */
static Escopo *topo_escopo = NULL;

/* Ponteiro para o escopo global (base da pilha) */
static Escopo *escopo_global = NULL;

/* Lista histórica de todos os símbolos inseridos (para impressão final) */
static Simbolo *hist_inicio = NULL;
static Simbolo *hist_fim = NULL;

static char *duplicar_str(const char *s)
{
    if (s == NULL)
        return NULL;
    size_t n = strlen(s) + 1;
    char *copia = (char *)malloc(n);
    if (copia == NULL) {
        fprintf(stderr, "Erro fatal: falta de memoria na tabela de simbolos.\n");
        exit(EXIT_FAILURE);
    }
    memcpy(copia, s, n);
    return copia;
}

void enter_scope(const char *nome_escopo)
{
    Escopo *novo = (Escopo *)malloc(sizeof(Escopo));
    if (novo == NULL) {
        fprintf(stderr, "Erro fatal: falta de memoria ao criar escopo.\n");
        exit(EXIT_FAILURE);
    }
    novo->nome = duplicar_str(nome_escopo ? nome_escopo : "bloco");
    novo->nivel = (topo_escopo == NULL) ? 0 : (topo_escopo->nivel + 1);
    novo->simbolos = NULL;
    novo->prox = topo_escopo;
    topo_escopo = novo;

    if (escopo_global == NULL) {
        escopo_global = novo;
    }
}

void leave_scope(void)
{
    if (topo_escopo == NULL)
        return;

    Escopo *removido = topo_escopo;
    topo_escopo = topo_escopo->prox;
    if (removido == escopo_global) {
        escopo_global = NULL;
    }
    /* Nota: NÃO damos free nos símbolos aqui pois eles permanecem na lista
       histórica (hist_inicio) para imprimir a Tabela de Símbolos ao final. */
    free(removido->nome);
    free(removido);
}

Simbolo *find_sym_current(const char *nome)
{
    if (topo_escopo == NULL || nome == NULL)
        return NULL;

    Simbolo *s = topo_escopo->simbolos;
    while (s != NULL) {
        if (strcmp(s->nome, nome) == 0)
            return s;
        s = s->prox;
    }
    return NULL;
}

Simbolo *find_sym(const char *nome)
{
    if (nome == NULL)
        return NULL;

    Escopo *e = topo_escopo;
    while (e != NULL) {
        Simbolo *s = e->simbolos;
        while (s != NULL) {
            if (strcmp(s->nome, nome) == 0)
                return s;
            s = s->prox;
        }
        e = e->prox;
    }
    return NULL;
}

Simbolo *find_sym_global(const char *nome)
{
    if (escopo_global == NULL || nome == NULL)
        return NULL;

    Simbolo *s = escopo_global->simbolos;
    while (s != NULL) {
        if (strcmp(s->nome, nome) == 0)
            return s;
        s = s->prox;
    }
    return NULL;
}

Simbolo *declare_sym(const char *nome, CategoriaSimbolo categoria, TipoDado tipo, int tamanho, int linha)
{
    if (topo_escopo == NULL) {
        fprintf(stderr, "Erro interno: tentativa de declarar '%s' sem escopo ativo.\n", nome);
        return NULL;
    }

    Simbolo *novo = (Simbolo *)calloc(1, sizeof(Simbolo));
    if (novo == NULL) {
        fprintf(stderr, "Erro fatal: falta de memoria ao declarar simbolo.\n");
        exit(EXIT_FAILURE);
    }

    novo->nome = duplicar_str(nome);
    novo->categoria = categoria;
    novo->tipo = tipo;
    novo->tamanho = tamanho;
    novo->escopo_nome = duplicar_str(topo_escopo->nome);
    novo->nivel_escopo = topo_escopo->nivel;
    novo->linha = linha;
    novo->num_params = 0;
    novo->params = NULL;

    /* Insere na lista encadeada do escopo ativo (para buscas léxicas) */
    novo->prox = topo_escopo->simbolos;
    topo_escopo->simbolos = novo;

    /* Insere ao final da lista histórica (para preservar a ordem na impressão) */
    novo->prox_hist = NULL;
    if (hist_fim == NULL) {
        hist_inicio = hist_fim = novo;
    } else {
        hist_fim->prox_hist = novo;
        hist_fim = novo;
    }

    return novo;
}

void adicionar_param_simbolo(Simbolo *func, TipoDado tipo_param)
{
    if (func == NULL)
        return;

    ParamInfo *p = (ParamInfo *)malloc(sizeof(ParamInfo));
    if (p == NULL) {
        fprintf(stderr, "Erro fatal: falta de memoria ao registrar parametro.\n");
        exit(EXIT_FAILURE);
    }
    p->tipo = tipo_param;
    p->prox = NULL;

    if (func->params == NULL) {
        func->params = p;
    } else {
        ParamInfo *atual = func->params;
        while (atual->prox != NULL) {
            atual = atual->prox;
        }
        atual->prox = p;
    }
    func->num_params++;
}

void init_symtab(void)
{
    /* Abre o escopo global (nível 0) */
    enter_scope("global");

    /* Funções pré-definidas da linguagem C- (Apêndice A do Louden):
     *   int input(void)
     *   void output(int x)
     */
    declare_sym("input", FUNCAO, INT, 0, 0);

    Simbolo *fn_output = declare_sym("output", FUNCAO, VOID, 0, 0);
    adicionar_param_simbolo(fn_output, INT);
}

static void registrar_ast_na_tabela(NoAST *no, const char *nome_fun_atual, int *cont_blocos)
{
    while (no != NULL) {
        switch (no->tipo_no) {
            case DECL_VAR:
                declare_sym(no->nome, VARIAVEL, no->tipo_dado, 0, no->linha);
                break;

            case DECL_VETOR:
                declare_sym(no->nome, VAR_VETOR, no->tipo_dado, no->val, no->linha);
                break;

            case DECL_FUN: {
                Simbolo *sym_fun = declare_sym(no->nome, FUNCAO, no->tipo_dado, 0, no->linha);
                enter_scope(no->nome);

                int blocos_locais = 0;
                NoAST *param = no->filho[0];
                while (param != NULL) {
                    if (param->tipo_no == PARAM_VETOR) {
                        declare_sym(param->nome, PAR_VETOR, param->tipo_dado, 0, param->linha);
                        adicionar_param_simbolo(sym_fun, INT_VETOR);
                    } else {
                        declare_sym(param->nome, PARAMETRO, param->tipo_dado, 0, param->linha);
                        adicionar_param_simbolo(sym_fun, param->tipo_dado);
                    }
                    param = param->prox;
                }

                if (no->filho[1] != NULL) {
                    /* Corpo da função compartilha o escopo da função */
                    registrar_ast_na_tabela(no->filho[1]->filho[0], no->nome, &blocos_locais);
                    registrar_ast_na_tabela(no->filho[1]->filho[1], no->nome, &blocos_locais);
                }

                leave_scope();
                break;
            }

            case BLOCO: {
                char nome_bloco[64];
                (*cont_blocos)++;
                if (nome_fun_atual != NULL) {
                    snprintf(nome_bloco, sizeof(nome_bloco), "%s.bloco%d", nome_fun_atual, *cont_blocos);
                } else {
                    snprintf(nome_bloco, sizeof(nome_bloco), "bloco%d", *cont_blocos);
                }
                enter_scope(nome_bloco);
                registrar_ast_na_tabela(no->filho[0], nome_fun_atual, cont_blocos);
                registrar_ast_na_tabela(no->filho[1], nome_fun_atual, cont_blocos);
                leave_scope();
                break;
            }

            case IF:
                registrar_ast_na_tabela(no->filho[1], nome_fun_atual, cont_blocos);
                registrar_ast_na_tabela(no->filho[2], nome_fun_atual, cont_blocos);
                break;

            case WHILE:
                registrar_ast_na_tabela(no->filho[1], nome_fun_atual, cont_blocos);
                break;

            default:
                break;
        }
        no = no->prox;
    }
}

void popular_tabela_simbolos(NoAST *raiz)
{
    int cont_blocos = 0;
    init_symtab();
    registrar_ast_na_tabela(raiz, NULL, &cont_blocos);
}

static const char *nome_categoria(CategoriaSimbolo cat)
{
    switch (cat) {
        case VARIAVEL:   return "Variavel";
        case VAR_VETOR:  return "Vetor";
        case PARAMETRO:  return "Parametro";
        case PAR_VETOR:  return "ParamVetor";
        case FUNCAO:     return "Funcao";
        default:         return "?";
    }
}

void imprimir_tabela_simbolos(void)
{
    printf("\n================================================================================\n");
    printf("                              TABELA DE SIMBOLOS\n");
    printf("================================================================================\n");
    printf("%-16s | %-12s | %-8s | %-12s | %-14s | %-5s\n",
           "Identificador", "Categoria", "Tipo", "Tam/Params", "Escopo", "Linha");
    printf("--------------------------------------------------------------------------------\n");

    Simbolo *s = hist_inicio;
    while (s != NULL) {
        char info_extra[32];
        if (s->categoria == VAR_VETOR) {
            snprintf(info_extra, sizeof(info_extra), "tam=%d", s->tamanho);
        } else if (s->categoria == FUNCAO) {
            snprintf(info_extra, sizeof(info_extra), "params=%d", s->num_params);
        } else if (s->categoria == PAR_VETOR) {
            snprintf(info_extra, sizeof(info_extra), "[]");
        } else {
            snprintf(info_extra, sizeof(info_extra), "-");
        }

        const char *tipo_str = (s->categoria == PAR_VETOR || s->categoria == VAR_VETOR)
                                   ? "int[]"
                                   : nome_tipo_dado(s->tipo);

        if (s->linha == 0) {
            printf("%-16s | %-12s | %-8s | %-12s | %-14s | %s\n",
                   s->nome, nome_categoria(s->categoria), tipo_str,
                   info_extra, s->escopo_nome, "(pre-def)");
        } else {
            printf("%-16s | %-12s | %-8s | %-12s | %-14s | %d\n",
                   s->nome, nome_categoria(s->categoria), tipo_str,
                   info_extra, s->escopo_nome, s->linha);
        }

        s = s->prox_hist;
    }
    printf("================================================================================\n");
}

void liberar_tabela_simbolos(void)
{
    while (topo_escopo != NULL) {
        leave_scope();
    }

    Simbolo *s = hist_inicio;
    while (s != NULL) {
        Simbolo *prox = s->prox_hist;
        ParamInfo *p = s->params;
        while (p != NULL) {
            ParamInfo *prox_p = p->prox;
            free(p);
            p = prox_p;
        }
        free(s->nome);
        free(s->escopo_nome);
        free(s);
        s = prox;
    }
    hist_inicio = hist_fim = NULL;
}
