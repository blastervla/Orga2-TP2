CC=gcc
CFLAGS=-lm -g
DEPS= libbmp.h utils.h
OBJ= main.o libbmp.o utils.o
BIN=noise

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)


$(BIN): $(OBJ)
	$(CC) -o $@ $^ $(CFLAGS)

.PHONY: clean

clean:
	$(RM) *.o
	$(RM) $(BIN)