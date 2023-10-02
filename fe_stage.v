 `include "define.vh" 


module FE_STAGE(
  input wire clk,
  input wire reset,
  input wire [`from_DE_to_FE_WIDTH-1:0] from_DE_to_FE,
  input wire [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,   
  input wire [`from_MEM_to_FE_WIDTH-1:0] from_MEM_to_FE,   
  input wire [`from_WB_to_FE_WIDTH-1:0] from_WB_to_FE, 
  output wire [`FE_latch_WIDTH-1:0] FE_latch_out
);

  `UNUSED_VAR (from_MEM_to_FE)
  `UNUSED_VAR (from_WB_to_FE)

  // I-MEM
  (* ram_init_file = `IDMEMINITFILE *)
  reg [`DBITS-1:0] imem [`IMEMWORDS-1:0];
 
  initial begin
      $readmemh(`IDMEMINITFILE , imem);
  end

  // Display memory contents with verilator 
  /*
  always @(posedge clk) begin
    for (integer i=0 ; i<`IMEMWORDS ; i=i+1) begin
        $display("%h", imem[i]);
    end
  end
  */

  /* pipeline latch */ 
  reg [`FE_latch_WIDTH-1:0] FE_latch;  // FE latch 
  wire valid_FE;
   
  `UNUSED_VAR(valid_FE)
  reg [`DBITS-1:0] PC_FE_latch; // PC latch in the FE stage   // you could use a part of FE_latch as a PC latch as well 
  
  reg [`DBITS-1:0] inst_count_FE; /* for debugging purpose */ 
  
  wire [`DBITS-1:0] inst_count_AGEX; /* for debugging purpose. resent the instruction counter */ 

  wire [`INSTBITS-1:0] inst_FE;  // instruction value in the FE stage 
  wire [`DBITS-1:0] pcplus_FE;  // pc plus value in the FE stage 
  wire stall_pipe_FE; // signal to indicate when a front-end needs to be stall
  
  wire [`FE_latch_WIDTH-1:0] FE_latch_contents;  // the signals that will be FE latch contents 
  
  // reading instruction from imem 
  assign inst_FE = imem[PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS]];  // this code works. imem is stored 4B together 
  
  // wire to send the FE latch contents to the DE stage 
  assign FE_latch_out = FE_latch; 
 

  // This is the value of "incremented PC", computed in the FE stage
  assign pcplus_FE = PC_FE_latch + `INSTSIZE;
  
   
   // the order of latch contents should be matched in the decode stage when we extract the contents. 
  assign FE_latch_contents = {
                                valid_FE, 
                                inst_FE, 
                                PC_FE_latch, 
                                pcplus_FE, // please feel free to add more signals such as valid bits etc. 
                                inst_count_FE,
                                 // if you add more bits here, please increase the width of latch in VX_define.vh 
                                predicted_address,
                                PHT_index
                                };




  // **TODO: Complete the rest of the pipeline 
  //assign stall_pipe_FE = 1;   // you need
  assign {
    stall_pipe_FE
  } = from_DE_to_FE[0]; 

  // all of the wires needed from AGEX to update BTB and PHT
  wire br_mispred_AGEX;  
  wire [`DBITS-1:0] br_target_AGEX;
  wire [7:0] PHT_index;
  wire [`DBITS-1:0] predicted_address;
  wire is_branch_inst;
  wire [`DBITS-1:0] PC_AGEX;

  assign {
    br_mispred_AGEX,
    br_target_AGEX,
    PHT_index,
    predicted_address,
    is_branch_inst,
    PC_AGEX
  } = from_AGEX_to_FE;

  always @ (*) begin
    if (is_branch_inst) begin
        // always update the btb to say this inst was a branch
        branch_target_buffer_DE[PC_AGEX[5:2]][58] <= 1'b1;
        branch_target_buffer_DE[PC_AGEX[5:2]][57:32] <= PC_AGEX[31:6];
        branch_target_buffer_DE[PC_AGEX[5:2]][31:0] <= predicted_address;
        if (br_mispred_AGEX) begin
            pattern_history_table_DE[PHT_index] <= 
                pattern_history_table_DE[PHT_index] == 0 
                ? 0 : pattern_history_table_DE[PHT_index] - 1;
        end
        else begin
            pattern_history_table_DE[PHT_index] <= 
                pattern_history_table_DE[PHT_index] == 3 
                ? 3 : pattern_history_table_DE[PHT_index] + 1;
        end
    end
  end

  // Lab 2: Branch prediction
  reg [26 + 1 + 32 - 1:0] branch_target_buffer_DE [0:15];
  reg [7:0] branch_history_register_DE;
  reg [1:0] pattern_history_table_DE [0:(2**8)-1];
  wire [7:0] PHT_index;
  reg [`DBITS-1:0] predicted_address;  
  
  // pattern history table (PHT) initialization
  initial begin
    // Each of the 2bit counter in the PHT is initialized with 01.
    for (integer i = 0; i <= 8'hFF; i++) 
      pattern_history_table_DE[i] = {2'b01};
  end
  always @ (posedge clk) begin
  /* you need to extend this always block */
   if (reset) begin 
      PC_FE_latch <= `STARTPC;
      inst_count_FE <= 1;  /* inst_count starts from 1 for easy human reading. 1st fetch instructions can have 1 */ 
      end 
    else if (br_mispred_AGEX)
      PC_FE_latch <= br_target_AGEX;
    else if (stall_pipe_FE) 
      PC_FE_latch <= PC_FE_latch; 
    else begin 
      // branch prediction goes here
      // access btb and branch predictor
        
       (branch_target_buffer_DE[PC_FE_latch[5:2]][57:32] == PC_FE_latch[31:6]
        &&
        // same index, but check to see if the branch was taken last time
        branch_target_buffer_DE[PC_FE_latch[5:2]][58] == 1'b1
        ) begin
            // btb hit
            // save the PHT index to send to EX stage
            PHT_index <= branch_history_register_DE ^ PC_FE_latch[9:2];

            // go look at the pattern history table that contains
            // 00 strongly not taken, 01 weakly not taken, 10 weakly taken, 11 strongly taken
            // if the counter is 2 or 3, predict taken
            if (pattern_history_table_DE[PHT_index] >= 2'd2) begin
                // $display("Predict taken");
                // this might need to be assigned to the predicted address instead.
                predicted_address <= branch_target_buffer_DE[PC_FE_latch[5:2]][31:0];
                PC_FE_latch <= predicted_address;
            end
            else
                PC_FE_latch <= pcplus_FE;
        end
      // if the outer branch fails, increment normally
      else
        // else just fetch pc + 4 normally
        PC_FE_latch <= pcplus_FE;
      inst_count_FE <= inst_count_FE + 1; 
      end
  end 
  
  

  always @ (posedge clk) begin
    if (reset) begin 
      FE_latch <= '0; 
    end else begin 
      if (br_mispred_AGEX)
        FE_latch <= '0;
      else if (stall_pipe_FE)
        FE_latch <= FE_latch; 
      else 
        FE_latch <= FE_latch_contents; 
    end  
  end

endmodule
