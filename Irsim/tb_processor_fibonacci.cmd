|
| tb_processor_fibonacci.cmd
|
| Irsim testbench for the pipelined processor with cache running
| Fibonacci.  Top-level signals carry a p_ prefix.
|
| The program fills cache line 0 with 1,2,3,5 and line 1 with
| 8,13,21,34, then falls through to an LD+ADD and a JAL-self.
|
| Expected final state:
|    R1=21  R2=34  R3=8  R4=0  R5=34  R6=2  R7=1
|    cache line 0 = 1, 2, 3, 5
|    cache line 1 = 8, 13, 21, 34
|    meta 0 = meta 1 = valid|dirty|tag = 110b
|
| Debug read-back is driven interactively after the script returns.
|

| Display vectors
vector instr_data p_instr_data_pi\[15\] p_instr_data_pi\[14\] p_instr_data_pi\[13\] p_instr_data_pi\[12\] p_instr_data_pi\[11\] p_instr_data_pi\[10\] p_instr_data_pi\[9\] p_instr_data_pi\[8\] p_instr_data_pi\[7\] p_instr_data_pi\[6\] p_instr_data_pi\[5\] p_instr_data_pi\[4\] p_instr_data_pi\[3\] p_instr_data_pi\[2\] p_instr_data_pi\[1\] p_instr_data_pi\[0\]
vector dbg_addr   p_dbg_addr_pi\[6\] p_dbg_addr_pi\[5\] p_dbg_addr_pi\[4\] p_dbg_addr_pi\[3\] p_dbg_addr_pi\[2\] p_dbg_addr_pi\[1\] p_dbg_addr_pi\[0\]
vector dbg_data   p_dbg_data_po\[15\] p_dbg_data_po\[14\] p_dbg_data_po\[13\] p_dbg_data_po\[12\] p_dbg_data_po\[11\] p_dbg_data_po\[10\] p_dbg_data_po\[9\] p_dbg_data_po\[8\] p_dbg_data_po\[7\] p_dbg_data_po\[6\] p_dbg_data_po\[5\] p_dbg_data_po\[4\] p_dbg_data_po\[3\] p_dbg_data_po\[2\] p_dbg_data_po\[1\] p_dbg_data_po\[0\]

ana p_clka p_clkb p_reset_pi p_instr_valid_pi p_load_done_pi p_ready_po p_halted_po instr_data dbg_addr dbg_data

clock p_clka 0 1 0 0
clock p_clkb 0 0 0 1

| --- Initialise every input to low ---
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

| PC 00  ADDI R1,R0,0      0x5200  = 0101 0010 0000 0000
h p_instr_data_pi\[14\]
h p_instr_data_pi\[12\]
h p_instr_data_pi\[9\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 01  ADDI R2,R0,1      0x5401  = 0101 0100 0000 0001
l p_instr_data_pi\[9\]
h p_instr_data_pi\[10\]
h p_instr_data_pi\[0\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 02  ADDI R3,R0,0      0x5600  = 0101 0110 0000 0000
l p_instr_data_pi\[0\]
h p_instr_data_pi\[9\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 03  ADDI R4,R0,8      0x5808  = 0101 1000 0000 1000
l p_instr_data_pi\[10\]
l p_instr_data_pi\[9\]
h p_instr_data_pi\[11\]
h p_instr_data_pi\[3\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 04  ADD  R5,R1,R2     0x1A50  = 0001 1010 0101 0000
l p_instr_data_pi\[14\]
l p_instr_data_pi\[3\]
h p_instr_data_pi\[9\]
h p_instr_data_pi\[6\]
h p_instr_data_pi\[4\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 05  ST   R3,R5,0      0xCEC0  = 1100 1110 1100 0000
l p_instr_data_pi\[12\]
l p_instr_data_pi\[4\]
h p_instr_data_pi\[15\]
h p_instr_data_pi\[14\]
h p_instr_data_pi\[10\]
h p_instr_data_pi\[7\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 06  ADDI R3,R3,1      0x56C1  = 0101 0110 1100 0001
l p_instr_data_pi\[15\]
l p_instr_data_pi\[11\]
h p_instr_data_pi\[12\]
h p_instr_data_pi\[0\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 07  ADD  R1,R2,R0     0x1280  = 0001 0010 1000 0000
l p_instr_data_pi\[14\]
l p_instr_data_pi\[10\]
l p_instr_data_pi\[6\]
l p_instr_data_pi\[0\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 08  ADD  R2,R5,R0     0x1540  = 0001 0101 0100 0000
l p_instr_data_pi\[9\]
l p_instr_data_pi\[7\]
h p_instr_data_pi\[10\]
h p_instr_data_pi\[8\]
h p_instr_data_pi\[6\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 09  ADDI R4,R4,-1     0x593F  = 0101 1001 0011 1111
l p_instr_data_pi\[10\]
l p_instr_data_pi\[6\]
h p_instr_data_pi\[14\]
h p_instr_data_pi\[11\]
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

| PC 10  BNEZ R4,-7        0xA839  = 1010 1000 0011 1001
l p_instr_data_pi\[14\]
l p_instr_data_pi\[12\]
l p_instr_data_pi\[8\]
l p_instr_data_pi\[2\]
l p_instr_data_pi\[1\]
h p_instr_data_pi\[15\]
h p_instr_data_pi\[13\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 11  LD   R7,R0,0      0xBE00  = 1011 1110 0000 0000
l p_instr_data_pi\[5\]
l p_instr_data_pi\[4\]
l p_instr_data_pi\[3\]
l p_instr_data_pi\[0\]
h p_instr_data_pi\[12\]
h p_instr_data_pi\[10\]
h p_instr_data_pi\[9\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 12  ADD  R6,R7,R7     0x1DF8  = 0001 1101 1111 1000
l p_instr_data_pi\[15\]
l p_instr_data_pi\[13\]
l p_instr_data_pi\[9\]
h p_instr_data_pi\[8\]
h p_instr_data_pi\[7\]
h p_instr_data_pi\[6\]
h p_instr_data_pi\[5\]
h p_instr_data_pi\[4\]
h p_instr_data_pi\[3\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 13  JAL  self         0x81FF  = 1000 0001 1111 1111
l p_instr_data_pi\[12\]
l p_instr_data_pi\[11\]
l p_instr_data_pi\[10\]
h p_instr_data_pi\[15\]
h p_instr_data_pi\[2\]
h p_instr_data_pi\[1\]
h p_instr_data_pi\[0\]
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| PC 14  HALT              0xF000  = 1111 0000 0000 0000
l p_instr_data_pi\[8\]
l p_instr_data_pi\[7\]
l p_instr_data_pi\[6\]
l p_instr_data_pi\[5\]
l p_instr_data_pi\[4\]
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

| PC 15  HALT              0xF000  (unchanged)
h p_instr_valid_pi
c 1
l p_instr_valid_pi
c 1

| --- load_done pulse ---
h p_load_done_pi
c 1
l p_load_done_pi

| --- Execute ---
c 160
