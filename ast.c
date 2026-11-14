/*
 * ast.c - Implementação da Árvore Sintática Abstrata (AST) para C-
 */
#include "ast.h"
#include <stdlib.h>
#include <string.h>

NoAST *criar_no(TipoNo tipo_no, int linha)
{
    NoAST *no = (NoAST *)calloc(1, sizeof(NoAST));
    if (no == NULL) {
        fprintf(stderr, "Erro fatal: falha de alocacao de memoria na AST.\n");
        exit(EXIT_FAILURE);
    }
    no->tipo_no = tipo_no;
    no->tipo_dado = VOID;
    no->linha = linha;
    return no;
}

NoAST *adicionar_irmao(NoAST *lista, NoAST *novo)
{
    if (lista == NULL)
        return novo;
    if (novo == NULL)
        return lista;

    NoAST *atual = lista;
    while (atual->prox != NULL) {
        atual = atual->prox;
    }
    atual->prox = novo;
    return lista;
}

const char *nome_tipo_dado(TipoDado tipo)
{
    switch (tipo) {
        case INT:       return "int";
        case VOID:      return "void";
        case INT_VETOR: return "int[]";
        case ERRO:      return "erro";
        default:        return "?";
    }
}

static void imprimir_indentacao(int nivel)
{
    for (int i = 0; i < nivel; i++) {
        printf("  ");
    }
}

void imprimir_ast(NoAST *raiz, int nivel)
{
    NoAST *no = raiz;
    while (no != NULL) {
        imprimir_indentacao(nivel);

        switch (no->tipo_no) {
            case DECL_VAR:
                printf("DeclVar: %s (tipo: %s) [linha %d]\n",
                       no->nome, nome_tipo_dado(no->tipo_dado), no->linha);
                break;

            case DECL_VETOR:
                printf("DeclVetor: %s[%d] (tipo: %s) [linha %d]\n",
                       no->nome, no->val, nome_tipo_dado(no->tipo_dado), no->linha);
                break;

            case DECL_FUN:
                printf("DeclFuncao: %s (retorno: %s) [linha %d]\n",
                       no->nome, nome_tipo_dado(no->tipo_dado), no->linha);
                if (no->filho[0] != NULL) {
                    imprimir_indentacao(nivel + 1);
                    printf("Parametros:\n");
                    imprimir_ast(no->filho[0], nivel + 2);
                } else {
                    imprimir_indentacao(nivel + 1);
                    printf("Parametros: (void)\n");
                }
                if (no->filho[1] != NULL) {
                    imprimir_indentacao(nivel + 1);
                    printf("Corpo:\n");
                    imprimir_ast(no->filho[1], nivel + 2);
                }
                break;

            case PARAM_VAR:
                printf("ParamVar: %s (tipo: %s) [linha %d]\n",
                       no->nome, nome_tipo_dado(no->tipo_dado), no->linha);
                break;

            case PARAM_VETOR:
                printf("ParamVetor: %s[] (tipo: %s) [linha %d]\n",
                       no->nome, nome_tipo_dado(no->tipo_dado), no->linha);
                break;

            case BLOCO:
                printf("Bloco [linha %d]\n", no->linha);
                if (no->filho[0] != NULL) {
                    imprimir_indentacao(nivel + 1);
                    printf("DeclaracoesLocais:\n");
                    imprimir_ast(no->filho[0], nivel + 2);
                }
                if (no->filho[1] != NULL) {
                    imprimir_indentacao(nivel + 1);
                    printf("Comandos:\n");
                    imprimir_ast(no->filho[1], nivel + 2);
                }
                break;

            case IF:
                printf("If [linha %d]\n", no->linha);
                imprimir_indentacao(nivel + 1);
                printf("Condicao:\n");
                imprimir_ast(no->filho[0], nivel + 2);
                imprimir_indentacao(nivel + 1);
                printf("Entao:\n");
                imprimir_ast(no->filho[1], nivel + 2);
                if (no->filho[2] != NULL) {
                    imprimir_indentacao(nivel + 1);
                    printf("Senao:\n");
                    imprimir_ast(no->filho[2], nivel + 2);
                }
                break;

            case WHILE:
                printf("While [linha %d]\n", no->linha);
                imprimir_indentacao(nivel + 1);
                printf("Condicao:\n");
                imprimir_ast(no->filho[0], nivel + 2);
                imprimir_indentacao(nivel + 1);
                printf("Corpo:\n");
                imprimir_ast(no->filho[1], nivel + 2);
                break;

            case RETURN:
                printf("Return [linha %d]\n", no->linha);
                if (no->filho[0] != NULL) {
                    imprimir_ast(no->filho[0], nivel + 1);
                }
                break;

            case ATRIB:
                printf("Atribuicao (=) (tipo: %s) [linha %d]\n",
                       nome_tipo_dado(no->tipo_dado), no->linha);
                imprimir_ast(no->filho[0], nivel + 1);
                imprimir_ast(no->filho[1], nivel + 1);
                break;

            case OP:
                printf("Op (%s) (tipo: %s) [linha %d]\n",
                       no->op ? no->op : "?", nome_tipo_dado(no->tipo_dado), no->linha);
                imprimir_ast(no->filho[0], nivel + 1);
                imprimir_ast(no->filho[1], nivel + 1);
                break;

            case VAR:
                printf("Var: %s (tipo: %s) [linha %d]\n",
                       no->nome, nome_tipo_dado(no->tipo_dado), no->linha);
                break;

            case VETOR:
                printf("Vetor: %s[...] (tipo: %s) [linha %d]\n",
                       no->nome, nome_tipo_dado(no->tipo_dado), no->linha);
                imprimir_indentacao(nivel + 1);
                printf("Indice:\n");
                imprimir_ast(no->filho[0], nivel + 2);
                break;

            case CHAMADA:
                printf("Chamada: %s() (tipo: %s) [linha %d]\n",
                       no->nome, nome_tipo_dado(no->tipo_dado), no->linha);
                if (no->filho[0] != NULL) {
                    imprimir_indentacao(nivel + 1);
                    printf("Argumentos:\n");
                    imprimir_ast(no->filho[0], nivel + 2);
                }
                break;

            case CONST:
                printf("Const: %d (tipo: %s) [linha %d]\n",
                       no->val, nome_tipo_dado(no->tipo_dado), no->linha);
                break;
        }

        no = no->prox;
    }
}

static int escrever_nos_dot(FILE *fp, NoAST *no, int *contador_id)
{
    if (no == NULL)
        return -1;

    int meu_id = (*contador_id)++;
    char rotulo[128];

    switch (no->tipo_no) {
        case DECL_VAR:
            snprintf(rotulo, sizeof(rotulo), "DeclVar\\n%s %s", nome_tipo_dado(no->tipo_dado), no->nome);
            break;
        case DECL_VETOR:
            snprintf(rotulo, sizeof(rotulo), "DeclVetor\\n%s %s[%d]", nome_tipo_dado(no->tipo_dado), no->nome, no->val);
            break;
        case DECL_FUN:
            snprintf(rotulo, sizeof(rotulo), "DeclFuncao\\n%s %s()", nome_tipo_dado(no->tipo_dado), no->nome);
            break;
        case PARAM_VAR:
            snprintf(rotulo, sizeof(rotulo), "Param\\n%s %s", nome_tipo_dado(no->tipo_dado), no->nome);
            break;
        case PARAM_VETOR:
            snprintf(rotulo, sizeof(rotulo), "ParamVetor\\n%s %s[]", nome_tipo_dado(no->tipo_dado), no->nome);
            break;
        case BLOCO:
            snprintf(rotulo, sizeof(rotulo), "Bloco");
            break;
        case IF:
            snprintf(rotulo, sizeof(rotulo), "If");
            break;
        case WHILE:
            snprintf(rotulo, sizeof(rotulo), "While");
            break;
        case RETURN:
            snprintf(rotulo, sizeof(rotulo), "Return");
            break;
        case ATRIB:
            snprintf(rotulo, sizeof(rotulo), "=");
            break;
        case OP:
            snprintf(rotulo, sizeof(rotulo), "Op: %s", no->op ? no->op : "?");
            break;
        case VAR:
            snprintf(rotulo, sizeof(rotulo), "Var: %s", no->nome);
            break;
        case VETOR:
            snprintf(rotulo, sizeof(rotulo), "Vetor: %s[]", no->nome);
            break;
        case CHAMADA:
            snprintf(rotulo, sizeof(rotulo), "Call: %s()", no->nome);
            break;
        case CONST:
            snprintf(rotulo, sizeof(rotulo), "Const: %d", no->val);
            break;
    }

    fprintf(fp, "    n%d [label=\"%s\\n(linha %d)\"];\n", meu_id, rotulo, no->linha);

    for (int i = 0; i < 3; i++) {
        NoAST *f = no->filho[i];
        while (f != NULL) {
            int id_filho = escrever_nos_dot(fp, f, contador_id);
            if (id_filho >= 0) {
                fprintf(fp, "    n%d -> n%d;\n", meu_id, id_filho);
            }
            f = f->prox;
        }
    }

    return meu_id;
}

int salvar_ast_dot(NoAST *raiz, const char *caminho_arquivo)
{
    FILE *fp = fopen(caminho_arquivo, "w");
    if (fp == NULL)
        return -1;

    fprintf(fp, "digraph AST {\n");
    fprintf(fp, "    node [shape=box, fontname=\"Courier\"];\n");
    fprintf(fp, "    n0 [label=\"Programa\"];\n");

    int contador_id = 1;
    NoAST *decl = raiz;
    while (decl != NULL) {
        int id_decl = escrever_nos_dot(fp, decl, &contador_id);
        if (id_decl >= 0) {
            fprintf(fp, "    n0 -> n%d;\n", id_decl);
        }
        decl = decl->prox;
    }

    fprintf(fp, "}\n");
    fclose(fp);
    return 0;
}

void liberar_ast(NoAST *raiz)
{
    while (raiz != NULL) {
        NoAST *prox = raiz->prox;
        for (int i = 0; i < 3; i++) {
            if (raiz->filho[i] != NULL) {
                liberar_ast(raiz->filho[i]);
            }
        }
        free(raiz->nome);
        free(raiz);
        raiz = prox;
    }
}
