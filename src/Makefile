# ************************************************************************* #
#   Organizacion del Computador II - Trabajo Practico 2                     #
# ************************************************************************* #

OPT = O0
ifdef C_OPT
	OPT = $(C_OPT)
endif

CFLAGS64 = -ggdb -Wall -Wno-unused-parameter -Wextra -std=c99 -no-pie -pedantic -m64 -$(OPT) -march=native
CFLAGS=$(CFLAGS64)

BUILD_DIR = build
BIN = tp2
BIN_IM2 = $(addsuffix _im2, $(BIN))
BIN_IM4 = $(addsuffix _im4, $(BIN))
BIN_IM8 = $(addsuffix _im8, $(BIN))

ifdef C_BIN
	BIN = $(C_BIN)
endif

FILTROS = Rombos Bordes Nivel
FILTROS_SIN_BORDES = Rombos Nivel

FILTROS_OBJ = $(addsuffix .o, $(FILTROS)) $(addsuffix _asm.o, $(FILTROS)) $(addsuffix _c.o, $(FILTROS))
FILTROS_IM2_OBJ = Bordes_im2_asm.o $(addsuffix _asm.o, $(FILTROS_SIN_BORDES)) $(addsuffix _c.o, $(FILTROS)) $(addsuffix .o, $(FILTROS))
FILTROS_IM4_OBJ = Bordes_im4_asm.o $(addsuffix _asm.o, $(FILTROS_SIN_BORDES)) $(addsuffix _c.o, $(FILTROS)) $(addsuffix .o, $(FILTROS))
FILTROS_IM8_OBJ = Bordes_im8_asm.o $(addsuffix _asm.o, $(FILTROS_SIN_BORDES)) $(addsuffix _c.o, $(FILTROS)) $(addsuffix .o, $(FILTROS))

LIBS_OBJS   = libbmp.o imagenes.o utils.o

MAIN_OBJS   = cli.o $(addsuffix .o, $(BIN))
MAIN_OBJS_CON_PATH = $(addprefix $(BUILD_DIR)/, $(MAIN_OBJS))

OBJS = $(MAIN_OBJS) $(LIBS_OBJS) $(FILTROS_OBJ)
OBJS_CON_PATH = $(addprefix $(BUILD_DIR)/, $(OBJS))

OBJS_IM2 = $(MAIN_OBJS) $(LIBS_OBJS) $(FILTROS_IM2_OBJ)
OBJS_IM2_CON_PATH = $(addprefix $(BUILD_DIR)/, $(OBJS_IM2))

OBJS_IM4 = $(MAIN_OBJS) $(LIBS_OBJS) $(FILTROS_IM4_OBJ)
OBJS_IM4_CON_PATH = $(addprefix $(BUILD_DIR)/, $(OBJS_IM4))

OBJS_IM8 = $(MAIN_OBJS) $(LIBS_OBJS) $(FILTROS_IM8_OBJ)
OBJS_IM8_CON_PATH = $(addprefix $(BUILD_DIR)/, $(OBJS_IM8))

.PHONY: all clean FORCE

all: FORCE $(BUILD_DIR)/$(BIN) $(BUILD_DIR)/$(BIN_IM2) $(BUILD_DIR)/$(BIN_IM4) $(BUILD_DIR)/$(BIN_IM8)

$(BUILD_DIR)/$(BIN): $(MAIN_OBJS_CON_PATH)
	$(CC) $(CFLAGS) $(OBJS_CON_PATH) -o $@ -lm

$(BUILD_DIR)/$(BIN_IM2): $(MAIN_OBJS_CON_PATH)
	$(CC) $(CFLAGS) $(OBJS_IM2_CON_PATH) -o $@ -lm

$(BUILD_DIR)/$(BIN_IM4): $(MAIN_OBJS_CON_PATH)
	$(CC) $(CFLAGS) $(OBJS_IM4_CON_PATH) -o $@ -lm

$(BUILD_DIR)/$(BIN_IM8): $(MAIN_OBJS_CON_PATH)
	$(CC) $(CFLAGS) $(OBJS_IM8_CON_PATH) -o $@ -lm

export CFLAGS64
FORCE:
	mkdir -p build
	make -C helper
	make -C filters

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $< -lm

clean:
	rm -fr $(BUILD_DIR)/*