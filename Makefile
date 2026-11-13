# Makefile provisório: só scanner e parser
#
#   make        gera o executável "cminus"
#   make clean  apaga os arquivos gerados
#
# No Windows com win_flex e win_bison:
#   make FLEX=win_flex BISON=win_bison

CC     = gcc
FLEX   = flex
BISON  = bison
CFLAGS = -std=gnu99 -Wall -Wextra -g

OBJS = parser.tab.o lex.yy.o

cminus: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

parser.tab.c parser.tab.h: parser.y
	$(BISON) -d -o parser.tab.c parser.y

lex.yy.c: scanner.l parser.tab.h
	$(FLEX) -olex.yy.c scanner.l

lex.yy.o: lex.yy.c
	$(CC) $(CFLAGS) -Wno-sign-compare -Wno-unused-function -c -o $@ $<

parser.tab.o: parser.tab.c
	$(CC) $(CFLAGS) -Wno-unused-function -c -o $@ $<

clean:
	rm -f cminus cminus.exe *.o parser.tab.c parser.tab.h lex.yy.c

.PHONY: clean
