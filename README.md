## Project Name

5 Stage Pipelined Processor with Cache

## Authors

Rocky Ren, Harry Zhu, Brandon Sung. Contact: [LR60@rice.edu](mailto:LR60@rice.edu)

## Memory capacity and the Cache details

Instruction memory: 16 words of 16 bits. Address width is 4 bit. The read is async. The write is synchronous on negedge clkb, used by the loader FSM during S_LOAD state for cache controller. 

Data Memory: 32 words of 16 bits. Address start from 0 to 31, using width of 5bits. The address 5'd24 is the stack base. The stack lives at the upper portion of the data memory address space, only by convention.  

Cache: Direct mapped, write back, write allocate. 
4 lines, each block has 4 words of 16 bits.  The tag is 1 bit at the MSB of addr_pi[4]. The index is 2 bits of addr_pi[3:2]. The word offset is the LSB two bits. 
ache Policy
Write-back, write-allocate with a 4-state FSM:

S0 (Idle/Action): On a hit, serve loads immediately or update the cache line (and mark dirty) for stores. On a miss, transition to S1 or S2.
S1 (Dirty writeback): If the evicted line is dirty and valid, write all 4 words of the old block back to DMEM. Then go to S2.
S2 (Fetch block): Read 4 words from DMEM for the requested address block. Then go to S3.
S3 (Install): Install the fetched block into the cache line, set valid=1, dirty=0, update the tag. Return to S0.
The stall signal is: stall_po = req_valid_pi && ((currentState != S0) || cache_miss) -- so the pipeline stalls whenever there is a cache miss or the cache FSM is still processing a miss.

A miss costs 3 extra cycles (S1->S2->S3 if dirty, or S2->S3 if clean) before the instruction can proceed.

## Top-Level Pin Interface (system_top, 46 signal pins total)

Inputs (28 pins):

- clka (1) -- Phase-1 clock, active high
- clkb (1) -- Phase-2 clock, active high, non-overlapping with clka
- reset_pi (1) -- Active-high synchronous reset
- instr_data_pi[15:0] (16) -- Instruction word for serial program loading
- instr_valid_pi (1) -- Strobe: latch current instr_data_pi into IMEM
- load_done_pi (1) -- Pulse to transition from S_LOAD to S_RUN
- dbg_addr_pi[6:0] (7) -- Debug read-back address

Outputs (18 pins):

- halted_po (1) -- High when HALT is decoded in the IF stage
- ready_po (1) -- High while in S_LOAD (ready to accept instructions)
- dbg_data_po[15:0] (16) -- Debug read-back data

Plus VDD and VSS power pads.

## Debug Read-Back Port

The debug port provides combinational (asynchronous) read access to all
internal storage arrays and the program counter. Drive dbg_addr_pi with
the desired 7-bit address; dbg_data_po returns the corresponding 16-bit
value after combinational propagation (no clock edge required).

Best used when the processor is halted or in S_LOAD to avoid reading
values that are mid-update. During S_RUN the port still works but the
returned value is a snapshot of the array at the instant of the read.

Address map (7-bit, hex):

All data words across the design are 16 bits. 

```
0x00 - 0x07  Register file R0 through R7
             Sub-address: addr[2:0] selects register index.

0x10 - 0x1F  Instruction memory IMEM[0] through IMEM[15]
             Sub-address: addr[3:0] selects the IMEM word.

0x20 - 0x3F  Data memory (backing store) DMEM[0] through DMEM[31]
             Sub-address: addr[4:0] selects the DMEM word.
             Note: if a cache line is dirty, DMEM may hold a stale
             value until the line is written back.

0x40 - 0x4F  Cache DATA_ARRAY: 4 lines x 4 words = 16 entries
             addr[3:2] = cache line index (0-3)
             addr[1:0] = word offset within the 64-bit block (0-3)
             Returns the 16-bit word from the selected position.

0x50 - 0x53  Cache metadata for lines 0 through 3
             addr[1:0] = cache line index
             Returns {13'b0, valid, dirty, tag} packed into 16 bits.
             Bit 2 = valid, bit 1 = dirty, bit 0 = tag.

0x58         Program counter (PC)
             Returns {12'b0, pc[3:0]}.

All other addresses return 0x0000.
```

Example usage from testbench or external controller:

1. Set dbg_addr_pi = 7'h02 to read register R2.
2. After combinational delay, dbg_data_po holds the 16-bit value of R2.
3. Set dbg_addr_pi = 7'h20 to read DMEM[0].
4. Set dbg_addr_pi = 7'h40 to read cache line 0, word 0.
5. Set dbg_addr_pi = 7'h50 to read cache metadata for line 0.

