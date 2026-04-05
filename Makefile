# Makefile para la calculadora multi-función (mfcalc)

CC = gcc
CFLAGS = -Wall
LDFLAGS = -lm

TARGET = mfcalc

all: $(TARGET)

# 1. Bison genera calc.tab.c y calc.tab.h
calc.tab.c calc.tab.h: calc.y calc.h
	bison -d calc.y

# 2. Flex genera lex.yy.c (necesita calc.tab.h y calc.h)
lex.yy.c: lexico.l calc.tab.h calc.h
	flex lexico.l

# 3. Compilar y enlazar todo
$(TARGET): calc.tab.c lex.yy.c inter.c
	$(CC) $(CFLAGS) -o $(TARGET) inter.c calc.tab.c lex.yy.c $(LDFLAGS)

clean:
	rm -f $(TARGET) calc.tab.c calc.tab.h lex.yy.c

.PHONY: all clean
