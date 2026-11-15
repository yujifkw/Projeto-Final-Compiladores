# Compilador C− (Projeto Final de Compiladores)

Compilador desenvolvido em **C** utilizando **Flex** e **Bison** para a linguagem **C− (C-Minus)**, conforme especificação da disciplina de Compiladores e Apêndice A do livro *Compiler Construction: Principles and Practice* (Kenneth C. Louden).

---

## Estado Atual do Projeto

| Módulo | Status | Arquivos |
| :--- | :---: | :--- |
| **1. Analisador Léxico (Scanner)** | Concluído | `scanner.l` |
| **2. Analisador Sintático (Parser) + AST** | Concluído | `parser.y`, `ast.h`, `ast.c` |
| **3. Tabela de Símbolos** | Concluído | `symtab.h`, `symtab.c` |
| **4. Analisador Semântico** | Pendente | — |
| **5. Código Intermediário (3 Endereços)** | Pendente | — |

---

## Estrutura do Repositório

- `scanner.l` — Analisador léxico em Flex (palavras-chave, identificadores, números com checagem de overflow, operadores, delimitadores e comentários `/* ... */` com detecção de comentário não fechado).
- `parser.y` — Analisador sintático em Bison com recuperação de erros (`error ;`), construção da AST e função `main`.
- `ast.h` / `ast.c` — Estrutura `NoAST`, criação e encadeamento de nós, impressão textual indentada, exportação para Graphviz (`ast.dot`) e liberação de memória.
- `symtab.h` / `symtab.c` — Tabela de Símbolos com pilha de escopos (`enter_scope` / `leave_scope`), histórico completo para exibição, funções pré-definidas `input()` e `output()` e impressão formatada.
- `Makefile` — Script de compilação compatível com Linux (`make`) e Windows (`mingw32-make` + WinFlexBison).
- `tests/` — Programas de exemplo e testes em C− (`gcd.cm`, `sort.cm`, `erro_lexico.cm`, `erro_sintatico.cm`).

---

## Pré-requisitos

- **GCC** (suporte a C99)
- **Flex** e **Bison** (no Windows: **WinFlexBison** e `mingw32-make`)
- **Make**

---

## Compilação e Execução

### Linux / WSL
```bash
make
./cminus tests/gcd.cm
```

### Windows (PowerShell / MinGW)
```powershell
mingw32-make
.\cminus.exe tests\gcd.cm
```

Para remover os arquivos gerados pela compilação (`.o`, `parser.tab.c`, `parser.tab.h`, `lex.yy.c`, `ast.dot` e executável):
```bash
make clean          # Linux
mingw32-make clean  # Windows
```

---

## Saídas e Tratamento de Erros

Quando a análise léxica e sintática é concluída sem erros, o compilador exibe e gera:
1. **Tabela de Símbolos** completa no terminal (incluindo `input`, `output` e todos os escopos globais, de função e blocos internos).
2. **Árvore Sintática Abstrata (AST)** em formato textual indentado no terminal.
3. **Arquivo `ast.dot`** no formato Graphviz para visualização gráfica da AST.

Em caso de erro, as mensagens seguem o padrão especificado:
- **Erro Léxico** (interrompe imediatamente a compilação):
  ```text
  ERRO LEXICO: "lexema" - LINHA: X
  ```
- **Erro Sintático** (com tentativa de recuperação até `;`):
  ```text
  ERRO SINTATICO: token inesperado "token", esperado "token" - LINHA: X
  ```

---

## Casos de Teste Disponíveis (`tests/`)

| Arquivo | Descrição |
| :--- | :--- |
| `tests/gcd.cm` | Algoritmo de Euclides para MDC (Louden, Apêndice A.3) |
| `tests/sort.cm` | Ordenação por seleção com vetores e blocos aninhados (Louden, Apêndice A.3) |
| `tests/erro_lexico.cm` | Teste de detecção de caractere inválido e interrupção imediata |
| `tests/erro_sintatico.cm` | Teste de detecção de erro sintático e recuperação |
