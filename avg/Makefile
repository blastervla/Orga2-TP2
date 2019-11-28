CC=gcc
DEPS= libbmp.h utils.h
OBJ= main.o libbmp.o utils.o

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $<


avg: $(OBJ)
	$(CC) -o $@ $^

.PHONY: clean

clean:
	rm *.o
