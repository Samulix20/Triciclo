import subprocess
import sys
import os
import pathlib
import argparse

# Import envirment variables when lib loaded
RV_CROSS = os.environ["RV_CROSS"]
RV_CC = os.environ["RV_CC"]
RV_CXX = os.environ["RV_CXX"]
RV_DMP = os.environ["RV_DMP"]

BSP_DIR = os.environ["BSP_DIR"]

RV_CC_FLAGS = [] 
for w in os.environ["RV_CC_FLAGS"].split(' '):
    RV_CC_FLAGS.append(w)

RV_CXX_FLAGS = [] 
for w in os.environ["RV_CXX_FLAGS"].split(' '):
    RV_CXX_FLAGS.append(w)

path_common = "test/bringup-bench/common"

####

def remove_all(l, v):
    return [i for i in l if i != v]

####

log_count = 0
log_enabled = True

def print_log(*args):
    global log_count, log_enabled

    if not log_enabled:
        return

    log_count += 1
    print(f"[{log_count}]", *args)

def print_log_stderr(r):

    if not log_enabled:
        return
    
    print(r, end='')


def reset_log_count():
    global log_count
    log_count = 0

def raise_shell_err(p, *args):
    if p.returncode != 0:
        print(f"Error {p.returncode} - {p.stderr.decode("utf-8")}", file=sys.stderr)
        raise Exception(*args)

def shell(*args):
    print_log(*args)
    p = subprocess.run(args, capture_output=True)
    raise_shell_err(p, *args)
    o = p.stdout.decode("utf-8")
    r = p.stderr.decode("utf-8")
    print_log_stderr(r)
    return o, r


#####

def find_srcs(d, *args):
    r = []
    for p in args:
        r += shell("find", d, "-name", p)[0][:-1].split('\n')
    return remove_all(r, "")

def src_is_cpp(src):
    return pathlib.Path(src).suffix in [".cpp", "cc"]

def srcs_are_cpp(srcs):
    for src in srcs:
        if src_is_cpp(src):
            return True
    return False

#####

def rvcomp(src, buildir, *extra_args):
    obj = f"{buildir}/{pathlib.Path(src).stem}.o"
    args = [*extra_args, "-c", src, "-o", obj]

    if src_is_cpp(src):
        shell(RV_CXX, *RV_CXX_FLAGS, *args)
    else:
        shell(RV_CC, *RV_CC_FLAGS, *args)
    return obj

def rvlink(srcs, objs, lds, target, *extra_args):
    args = [*extra_args, "-T", lds, *objs, "-o", target]

    if srcs_are_cpp(srcs):
        shell(RV_CXX, *RV_CXX_FLAGS, *args)
    else:
        shell(RV_CC, *RV_CC_FLAGS, *args)

    os.system(f"""
        {RV_DMP} -S {target} > {target}.dmp
    """)
    
    return target

#####

def compile_dir(d, buildir, *extra_args):
    shell("mkdir", "-p", buildir)
    srcs = find_srcs(d, "*.S", "*.c", "*.cpp")
    objs = [rvcomp(src, buildir, *extra_args) for src in srcs]
    return srcs, objs

def create_linker_script(buildir, linker_file):
    shell("mkdir", "-p", buildir)
    lds = f"{buildir}/{linker_file}"
    with open(lds, "w") as f:
        o, _ = shell(RV_CC, "-E", "-P", "-x", "c", "-I.", f"{BSP_DIR}/{linker_file}.in")
        f.write(o)
    return lds

def compile_bsp(buildir, linker_file):
    lds = create_linker_script(buildir, linker_file)
    return *compile_dir(f"{BSP_DIR}", buildir), lds

#####

tb_common_params = ""
linker_file_path = "linker.lds"
testbench_obj = "Vtop"

def build_project(projectdir, buildir, targetname, *extra_args):
    bsp_srcs, bsp_objs, lds = compile_bsp(f"{buildir}/{projectdir}/bsp", linker_file_path)
    srcs, objs = compile_dir(projectdir, f"{buildir}/{projectdir}", *extra_args)
    target = f"{buildir}/{projectdir}/{targetname}"
    rvlink(srcs, bsp_objs + objs, lds, target)

def run_testbench(p):
    os.system(f"./obj_dir/{testbench_obj} {p} {tb_common_params}")

def build_and_run(projectdir, buildir, *extra_args):
    build_project(projectdir, buildir, "main.elf", *extra_args)
    run_testbench(f"-e {buildir}/{projectdir}/main.elf")

def build_and_run_wave(projectdir, buildir, *extra_args):
    shell("make", "wave_only")
    build_project(projectdir, buildir, "main.elf", *extra_args)
    run_testbench(f"-e {buildir}/{projectdir}/main.elf")

