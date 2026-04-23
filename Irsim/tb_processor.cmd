|
| tb_processor.cmd
|
| Irsim testbench for the pipelined processor with cache.
| Top-level signals carry a p_ prefix in the routed netlist.
|
| Flow:
|    1. Hold reset for 3 clock cycles.
|    2. Release reset, idle one cycle.
|    3. Load 16 instruction words serially.  Each load pulses
|       p_instr_valid_pi high for one cycle with the word on
|       p_instr_data_pi, then low for one cycle.
|    4. Pulse p_load_done_pi for one cycle, enter S_RUN.
|    5. Execute for many cycles, processor settles on JAL-self.
|
| Debug read-back of registers, cache, and PC is driven
| interactively at the irsim prompt after the script returns
| by setting p_dbg_addr_pi bits with h or l and stepping with
| c or s.
|
| Expected register-file state after execution:
|    R0=0  R1=0  R2=3  R3=8  R4=0  R5=8  R6=8  R7=11
| Expected cache:  line 0 word 0 = 8, meta 0 valid=dirty=1 tag=0.
|

| Display vectors
vector instr_data p_instr_data_pi\[15\] p_instr_data_pi\[14\] p_instr_data_pi\[13\] p_instr_data_pi\[12\] p_instr_data_pi\[11\] p_instr_data_pi\[10\] p_instr_data_pi\[9\] p_instr_data_pi\[8\] p_instr_data_pi\[7\] p_instr_data_pi\[6\] p_instr_data_pi\[5\] p_instr_data_pi\[4\] p_instr_data_pi\[3\] p_instr_data_pi\[2\] p_instr_data_pi\[1\] p_instr_data_pi\[0\]
vector dbg_addr   p_dbg_addr_pi\[6\] p_dbg_addr_pi\[5\] p_dbg_addr_pi\[4\] p_dbg_addr_pi\[3\] p_dbg_addr_pi\[2\] p_dbg_addr_pi\[1\] p_dbg_addr_pi\[0\]
vector dbg_data   p_dbg_data_po\[15\] p_dbg_data_po\[14\] p_dbg_data_po\[13\] p_dbg_data_po\[12\] p_dbg_data_po\[11\] p_dbg_data_po\[10\] p_dbg_data_po\[9\] p_dbg_data_po\[8\] p_dbg_data_po\[7\] p_dbg_data_po\[6\] p_dbg_data_po\[5\] p_dbg_data_po\[4\] p_dbg_data_po\[3\] p_dbg_data_po\[2\] p_dbg_data_po\[1\] p_dbg_data_po\[0\]

ana p_clka p_clkb p_reset_pi p_instr_valid_pi p_load_done_pi p_ready_po p_halted_po instr_data dbg_addr dbg_data

| Two-phase non-overlapping clock
clock p_clka 0 1 0 0
clock p_clkb 0 0 0 1

| --- Initialise every input to low so nothing starts X ---
l p_reset_pi
l p_instr_valid_pi
l p_load_done_pi
l p_instr_data_pi\[15\]
l p_instr_data_pi\[14\]
l p_instr_data_pi\[13\]
l p_instr_data_pi\[12\]
l p_instr_data_pi\[11\]
l p_instr_data_pi\[10\]
l p_instr_data_pi\[9\]
l p_instr_data_pi\[8\]
l p_instr_data_pi\[7\]
l p_instr_data_pi\[6\]
l p_instr_data_pi\[5\]
l p_instr_data_pi\[4\]
l p_instr_data_pi\[3\]
l p_instr_data_pi\[2\]
l p_instr_data_pi\[1\]
l p_instr_data_pi\[0\]
l p_dbg_addr_pi\[6\]
l p_dbg_addr_pi\[5\]
l p_dbg_addr_pi\[4\]
l p_dbg_addr_pi\[3\]
l p_dbg_addr_pi\[2\]
l p_dbg_addr_pi\[1\]
l p_dbg_addr_pi\[0\]

| --- Reset for 3 cycles ---
h p_reset_pi
c 3
l p_reset_pi
c 1

| --- Load 16 instructions ---

| PC 00  ADDI R1,R0,5      0x5205  = 0101 0010 0000 0101
h p_instr_data_pi\[14\]
h p_instr_data_pi\[12\]
h p_instr_data_pi\[9\]
h p_instr_data_pi\[2\]
h p_instr_data_pi\[0\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 01  ADDI R2,R0,3      0x5403  = 0101 0100 0000 0011
l p_instr_data_pi\[9\]
l p_instr_data_pi\[2\]
h p_instr_data_pi\[10\]
h p_instr_data_pi\[1\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 02  ADD  R3,R1,R2     0x1650  = 0001 0110 0101 0000
l p_instr_data_pi\[14\]
l p_instr_data_pi\[1\]
l p_instr_data_pi\[0\]
h p_instr_data_pi\[9\]
h p_instr_data_pi\[6\]
h p_instr_data_pi\[4\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 03  ST   R0,R3,0      0xC0C0  = 1100 0000 1100 0000
l p_instr_data_pi\[12\]
l p_instr_data_pi\[10\]
l p_instr_data_pi\[9\]
l p_instr_data_pi\[4\]
h p_instr_data_pi\[15\]
h p_instr_data_pi\[14\]
h p_instr_data_pi\[7\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 04  ADDI R4,R0,0      0x5800  = 0101 1000 0000 0000
l p_instr_data_pi\[15\]
l p_instr_data_pi\[7\]
l p_instr_data_pi\[6\]
h p_instr_data_pi\[12\]
h p_instr_data_pi\[11\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 05  LD   R5,R4,0      0xBB00  = 1011 1011 0000 0000
h p_instr_data_pi\[15\]
h p_instr_data_pi\[13\]
h p_instr_data_pi\[9\]
h p_instr_data_pi\[8\]
l p_instr_data_pi\[14\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 06  ADDI R1,R1,-1     0x527F  = 0101 0010 0111 1111
l p_instr_data_pi\[15\]
l p_instr_data_pi\[13\]
l p_instr_data_pi\[11\]
l p_instr_data_pi\[8\]
h p_instr_data_pi\[14\]
h p_instr_data_pi\[6\]
h p_instr_data_pi\[5\]
h p_instr_data_pi\[4\]
h p_instr_data_pi\[3\]
h p_instr_data_pi\[2\]
h p_instr_data_pi\[1\]
h p_instr_data_pi\[0\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 07  BNEZ R1,-2        0xA23E  = 1010 0010 0011 1110
l p_instr_data_pi\[14\]
l p_instr_data_pi\[12\]
l p_instr_data_pi\[6\]
l p_instr_data_pi\[0\]
h p_instr_data_pi\[15\]
h p_instr_data_pi\[13\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 08  LD   R6,R0,0      0xBC00  = 1011 1100 0000 0000
l p_instr_data_pi\[9\]
l p_instr_data_pi\[5\]
l p_instr_data_pi\[4\]
l p_instr_data_pi\[3\]
l p_instr_data_pi\[2\]
l p_instr_data_pi\[1\]
h p_instr_data_pi\[11\]
h p_instr_data_pi\[10\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 09  ADD  R7,R6,R2     0x1F90  = 0001 1111 1001 0000
l p_instr_data_pi\[15\]
l p_instr_data_pi\[13\]
h p_instr_data_pi\[9\]
h p_instr_data_pi\[8\]
h p_instr_data_pi\[7\]
h p_instr_data_pi\[4\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 10  JAL  self         0x81FF  = 1000 0001 1111 1111
l p_instr_data_pi\[12\]
l p_instr_data_pi\[11\]
l p_instr_data_pi\[10\]
l p_instr_data_pi\[9\]
l p_instr_data_pi\[4\]
h p_instr_data_pi\[15\]
h p_instr_data_pi\[8\]
h p_instr_data_pi\[6\]
h p_instr_data_pi\[5\]
h p_instr_data_pi\[3\]
h p_instr_data_pi\[2\]
h p_instr_data_pi\[1\]
h p_instr_data_pi\[0\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 11  HALT             0xF000  = 1111 0000 0000 0000
l p_instr_data_pi\[8\]
l p_instr_data_pi\[7\]
l p_instr_data_pi\[6\]
l p_instr_data_pi\[5\]
l p_instr_data_pi\[3\]
l p_instr_data_pi\[2\]
l p_instr_data_pi\[1\]
l p_instr_data_pi\[0\]
h p_instr_data_pi\[14\]
h p_instr_data_pi\[13\]
h p_instr_data_pi\[12\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 12  HALT             0xF000  (data unchanged)
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 13  HALT             0xF000
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 14  HALT             0xF000
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 15  HALT             0xF000
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| --- load_done pulse, enter S_RUN ---
h p_load_done_pi
c 1
l p_load_done_pi

| --- Execute ---
c 80
