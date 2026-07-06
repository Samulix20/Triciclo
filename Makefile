-include config.mk

# Verilator build
obj_dir/${VERILATED_MODULE}: obj_dir/.verilator.stamp
	make -C obj_dir -f ${VERILATED_MODULE}.mk

obj_dir/.verilator.stamp: \
	config.mk Makefile rvtarget.h \
	$(CPP_SRC) $(CPP_HDR) $(FINAL_MODULES)

	${VV} -F modules/icb/icb.f -F triciclo.f testbench/sim/top.sv \
	-Wall --top-module ${TOP_MODULE} \
	--x-assign unique --x-initial unique $(VTRACE_FLAGS) \
	--cc -CFLAGS "-I$(PWD) $(CPP_TB_FLAGS) $(CPP_TRACE_FLAG)" \
	--exe $(CPP_SRC)

	@touch obj_dir/.verilator.stamp

lint:
	${VV} -F modules/icb/icb.f -F triciclo.f testbench/sim/top.sv \
	-Wall --top-module ${TOP_MODULE} --lint-only

# Testing
test: clean
	python scripts/basic_test.py

# Run the python make scripts
py: obj_dir/${VERILATED_MODULE}
	python make.py

# Wave (gtkwave) trace visualizer
wave_only: clean
	make VTRACE_FLAGS="--trace --trace-structs" CPP_TRACE_FLAG="-DTRACE_WAVE"

wave: wave_only

# Clang linter tool, creates compile_commands.json
bear: clean
	bear -- make

# Cleanup
clean:
	rm -rf *.vcd *.dump
	rm -rf obj_dir build

run_linux: clean
	make
	./obj_dir/Vtop -b examples/linux/Image --echo --it

cinit:
	cd examples/linux; make all_cinit

busybox:
	cd examples/linux; make all_busybox

kconf:
	cd examples/linux; make kconf

bbconf:
	cd examples/linux; make bbconf
