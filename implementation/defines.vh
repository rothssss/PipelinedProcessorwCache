// Include this header in every source or testbench file. 

`ifndef DEFINES_VH
`define DEFINES_VH

// Opcodes (instruction bits [15:12])
`define NOP   4'b0000
`define ADD   4'b0001
`define NOT   4'b0010
`define AND   4'b0011
`define XOR   4'b0100
`define ADDI  4'b0101
`define SR    4'b0110
`define SL    4'b0111
`define JAL   4'b1000
`define RET   4'b1001
`define BNEZ  4'b1010
`define LD    4'b1011
`define ST    4'b1100
`define HALT  4'b1111

// programs use DMEM[STACK_BASE..31] as the stack.
`define STACK_BASE 5'd24

`endif 
