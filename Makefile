# ============================================================================
# Makefile do compilador C- (só scanner e parser)
#   make         gera o executável "cminus" (no MinGW: mingw32-make)
#   make clean   apaga os arquivos gerados
#
# No Windows com win_flex e win_bison:
#   make FLEX=win_flex BISON=win_bison
# ============================================================================


# ---- Variáveis -------------------------------------------------------------
# Servem para não repetir os nomes e para poder trocar tudo num lugar só.
# Para usar uma variável, escreva $(NOME).

# Compilador de C.
CC     = gcc

# Gerador do scanner (lê scanner.l e gera código C).
FLEX   = flex

# Gerador do parser (lê parser.y e gera código C).
BISON  = bison

# Opções do compilador:
#   -std=gnu99  usa o padrão C99 com extensões do GNU
#   -Wall       liga os avisos mais comuns
#   -Wextra     liga avisos extras
#   -g          guarda informações para depuração
CFLAGS = -std=gnu99 -Wall -Wextra -g

# Lista dos arquivos objeto (.o) que formam o programa. Um .o é um arquivo C
# já traduzido para linguagem de máquina, mas ainda não pronto para executar.
OBJS = parser.tab.o lex.yy.o


# ---- Regra principal -------------------------------------------------------
# É a primeira regra do arquivo, então é a que roda quando você digita só
# "make". Ela junta todos os .o no executável final.
#   $@  é o nome do alvo (aqui, cminus)
#   $(OBJS) é a lista de objetos definida acima
cminus: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)


# ---- Geração do parser (Bison) --------------------------------------------
# Lê parser.y e gera dois arquivos:
#   parser.tab.c  o código do parser
#   parser.tab.h  a lista de tokens, que o scanner também usa
# A opção -d pede o arquivo .h e -o escolhe o nome do arquivo .c.
parser.tab.c parser.tab.h: parser.y
	$(BISON) -d -o parser.tab.c parser.y


# ---- Geração do scanner (Flex) --------------------------------------------
# Lê scanner.l e gera lex.yy.c. Depende de parser.tab.h porque o scanner usa
# os nomes dos tokens, então o Bison roda antes do Flex.
# O -o fica colado no nome do arquivo porque o Flex 2.5.4 exige assim.
lex.yy.c: scanner.l parser.tab.h
	$(FLEX) -olex.yy.c scanner.l


# ---- Compilação dos arquivos gerados ---------------------------------------
# Transforma cada .c em um .o. A opção -c significa "só compilar, não juntar
# ainda". Os -Wno-... desligam avisos que o código gerado pelo Flex e pelo
# Bison costuma dar e que não são erros nossos.
#   $@  é o nome do alvo (o .o)
#   $<  é a primeira dependência (o .c)
lex.yy.o: lex.yy.c
	$(CC) $(CFLAGS) -Wno-sign-compare -Wno-unused-function -c -o $@ $<

parser.tab.o: parser.tab.c
	$(CC) $(CFLAGS) -Wno-unused-function -c -o $@ $<


# ---- Limpeza ---------------------------------------------------------------
# Apaga o executável e todos os arquivos gerados, deixando só os que você
# escreveu. O comando rm não existe no PowerShell; se der erro, apague à mão
# ou rode pelo Git Bash.
clean:
	rm -f cminus cminus.exe *.o parser.tab.c parser.tab.h lex.yy.c

# Diz ao make que "clean" é um comando, e não um arquivo. Sem isso, se
# existisse um arquivo chamado clean, o make acharia que não há nada a fazer.
.PHONY: clean


# como rodar no terminal do vscode:
# mingw32-make
# .\cminus.exe t1.cm
# ( é necessário criar um arquivo t1.cm na pasta com o código que será testado)
