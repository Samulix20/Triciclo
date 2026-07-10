# Makefile para el testbench del Debug Module (Verilator + GoogleTest)
#
# Estructura esperada:
#   ./rtl/debug_module.sv
#   ./rtl/debug_module_pkg.sv
#   ./tests/testbench.cpp
#   ./tests/triciclo_pkg.sv
#
# Uso:
#   make test    -> compila (si hace falta) y ejecuta los tests
#   make build   -> solo compila
#   make clean   -> borra los artefactos de build

VERILATOR   ?= verilator
TOP_MODULE  := debug_module
PREFIX      := V$(TOP_MODULE)

RTL_DIR     := rtl
TEST_DIR    := testbench
OBJ_DIR     := obj_dir

# Orden de los paquetes/módulos: triciclo_pkg -> debug_module_pkg -> debug_module
# (debug_module_pkg importa triciclo_pkg, y debug_module importa ambos)
SRCS := $(TEST_DIR)/triciclo_pkg.sv \
        $(RTL_DIR)/debug_module_pkg.sv \
        $(RTL_DIR)/debug_module.sv

TB_SRC := $(TEST_DIR)/testbench.cpp

VERILATOR_FLAGS := -Wall -Wno-UNUSEDSIGNAL -Wno-EOFNEWLINE
BIN := $(OBJ_DIR)/$(PREFIX)

.PHONY: all test build run clean

all: test

build: $(BIN)

$(BIN): $(SRCS) $(TB_SRC)
	$(VERILATOR) $(VERILATOR_FLAGS) --cc $(SRCS) \
	    --top-module $(TOP_MODULE) --prefix $(PREFIX) \
	    --exe $(abspath $(TB_SRC)) \
	    --Mdir $(OBJ_DIR) \
	    -CFLAGS "-std=c++17" \
	    -LDFLAGS "-lgtest -lgtest_main -pthread" \
	    --build

test: build
	./$(BIN)

run: test

clean:
	rm -rf $(OBJ_DIR)
