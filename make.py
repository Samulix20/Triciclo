import scripts.build as mk

def fpga_tests():
    mk.tb_common_params = "--max-time 500000"
    mk.linker_file_path = "linker_fpga.lds"
    mk.testbench_obj = "Vfpga_top"
    mk.log_enabled = False
    
    mk.build_and_run("examples/c_hello_world", "build")
    print()
    mk.build_and_run("examples/aclint", "build")
    print()
    mk.build_and_run("examples/ecall", "build")
    print()

if __name__ == "__main__":

    # Examples
    #mk.build_and_run("examples/axi_test", "build")
    #mk.build_and_run_log("examples/c_hello_world", "build", "out", "prof")
    #mk.build_and_run_trace("examples/c_hello_world", "build", "trace.trace", "trace.kanata")
    #mk.build_and_run_bare("examples/bare", "build", "trace.trace", "trace.kanata")
    #mk.build_and_run_wave("examples/aclint", "build")
    #mk.build_and_run_it("examples/echo", "build")

    #fpga_tests()

    mk.build_and_run_wave("examples/aclint", "build")
