# ============================================================================
# Makefile do compilador C- (Scanner, Parser e AST)
#   make         gera o executável "cminus" (no MinGW: mingw32-make)
#   make clean   apaga os arquivos gerados
# ============================================================================

CC     = gcc
CFLAGS = -std=gnu99 -Wall -Wextra -g

ifeq ($(OS),Windows_NT)
    WINGET_BISON := $(wildcard $(LOCALAPPDATA)/Microsoft/WinGet/Packages/WinFlexBison*/win_bison.exe)
    WINGET_FLEX  := $(wildcard $(LOCALAPPDATA)/Microsoft/WinGet/Packages/WinFlexBison*/win_flex.exe)
    ifneq ($(WINGET_BISON),)
        BISON = "$(firstword $(WINGET_BISON))"
        FLEX  = "$(firstword $(WINGET_FLEX))"
    else
        BISON = win_bison
        FLEX  = win_flex
    endif
else
    FLEX  = flex
    BISON = bison
endif

OBJS = parser.tab.o lex.yy.o ast.o

cminus: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

parser.tab.c parser.tab.h: parser.y ast.h
	$(BISON) -d -o parser.tab.c parser.y

lex.yy.c: scanner.l parser.tab.h ast.h
	$(FLEX) -olex.yy.c scanner.l

lex.yy.o: lex.yy.c
	$(CC) $(CFLAGS) -Wno-sign-compare -Wno-unused-function -c -o $@ $<

parser.tab.o: parser.tab.c
	$(CC) $(CFLAGS) -Wno-unused-function -c -o $@ $<

ast.o: ast.c ast.h
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
ifeq ($(OS),Windows_NT)
	-del /Q cminus.exe *.o parser.tab.c parser.tab.h lex.yy.c ast.dot 2>NUL
else
	rm -f cminus cminus.exe *.o parser.tab.c parser.tab.h lex.yy.c ast.dot
endif

.PHONY: clean
