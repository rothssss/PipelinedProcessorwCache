## Project Name ##
5 Stage Pipelined Processor with Cache

## Authors ##
Rocky Ren, Harry Zhu, Brandon Sung. Contact: LR60@rice.edu


## Memory capacity and the Cache details ##
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