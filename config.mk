# Custom verilator instalation
#VERILATOR_ROOT := /path/to/verilator
#VV := ${VERILATOR_ROOT}/bin/verilator

# Package manager verilator instalation
VV := verilator

# Config flag for optimized verilator
# !! Increases compile time
# VVOPT := -O3

TARGET_TB = sim

ifeq ($(TARGET_TB), sim)

export TOP_MODULE := top
export CPP_SRC := testbench/testbench.cpp

else

export TOP_MODULE := fpga_top
export CPP_SRC := testbench/fpga_tb.cpp

endif

VERILATED_MODULE := V${TOP_MODULE}

VERILOG_CORE_MODULES := \
	$(shell find rtl/pkg -name '*.sv') \
	$(shell find rtl/fpga -name '*.sv') \
	$(shell find rtl/top -name '*.sv')

FINAL_MODULES := $(VERILOG_CORE_MODULES)

CPP_TB_FLAGS := -march=native -std=c++20 -Wall -Wextra

PWD := $(realpath .)

# RISC-V Cross compiler
export RV_CROSS := riscv64-unknown-elf-
export RV_CC := $(RV_CROSS)gcc
export RV_CXX := $(RV_CROSS)g++
export RV_DMP := $(RV_CROSS)objdump

export BSP_DIR := bsp

export ARCH_FLAGS := -march=rv32i_zmmul_zicsr -mabi=ilp32

export INCLUDE_FLAGS := -I$(BSP_DIR) -I.

export OPT_FLAGS := \
	-fdata-sections -ffunction-sections -Wl,--gc-sections,-S \
	-Wall -Wextra -O3

export RV_BARE_CXX_FLAGS := \
	-fno-exceptions -fno-unwind-tables -fno-rtti

export RV_CC_FLAGS := $(OPT_FLAGS) $(ARCH_FLAGS) $(INCLUDE_FLAGS)
export RV_CXX_FLAGS := $(RV_CC_FLAGS) $(RV_BARE_CXX_FLAGS)

