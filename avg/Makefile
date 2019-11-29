CC=gcc
DEPS= libbmp.h utils.h
OBJ= main.o libbmp.o utils.o
BIN=avg

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $<


$(BIN): $(OBJ)
	$(CC) -o $@ $^

.PHONY: clean

clean:
	$(RM) *.o
	$(RM) $(BIN)
