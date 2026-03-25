OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
	bootrom (wxa) : ORIGIN = 0x00001000, LENGTH = 1K
	ram (wxa) : ORIGIN = 0x80000000, LENGTH = 32K
}

SECTIONS
{
	.boot : { KEEP(*(.boot)) } >bootrom

	.init : { *(.init) } >ram
	.text : { *(.text) } >ram
	.data : { *(.data) } >ram
	.sdata : { *(.sdata) } >ram
	.bss : { *(.bss) } >ram
	.sbss : { *(.sbss) } >ram
	.stack :
	{
		. = ALIGN(16);
		. += 800;
		_stack_top = .;
	} >ram
}
