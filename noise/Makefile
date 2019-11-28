CC=gcc
CFLAGS=-lm -g
DEPS= libbmp.h utils.h
OBJ= main.o libbmp.o utils.o

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)


noise: $(OBJ)
	$(CC) -o $@ $^ $(CFLAGS)

.PHONY: clean

clean:
	rm *.o