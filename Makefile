-include config.mk


# Verilator build
obj_dir/${VERILATED_MODULE}: obj_dir/.verilator.stamp
	make -C obj_dir -f ${VERILATED_MODULE}.mk

obj_dir/.verilator.stamp: \
	config.mk Makefile rvtarget.h \
	$(CPP_SRC) $(CPP_HDR) $(FINAL_MODULES)

	${VV} $(FINAL_MODULES) -Irtl/pkg \
	-Wall --top-module ${TOP_MODULE} \
	--x-assign unique --x-initial unique $(VTRACE_FLAGS) \
	--cc -CFLAGS "-I$(PWD) $(CPP_TB_FLAGS) $(CPP_TRACE_FLAG)" \
	--exe $(CPP_SRC)

	@touch obj_dir/.verilator.stamp

# Lint only
lint:
	${VV} -Irtl/pkg --lint-only -Wall $(VERILOG_CORE_MODULES) --top-module ${TOP_MODULE}

# Testing
test: clean
	python scripts/basic_test.py

# Run the python make scripts
py: obj_dir/${VERILATED_MODULE}
	python make.py

# Wave (gtkwave) trace visualizer
wave_only: clean
	make VTRACE_FLAGS="--trace --trace-structs" CPP_TRACE_FLAG="-DTRACE_WAVE"

# Clang linter tool, creates compile_commands.json
bear: clean
	bear -- make

# Cleanup
clean:
	rm -rf *.vcd *.dump
	rm -rf obj_dir build
