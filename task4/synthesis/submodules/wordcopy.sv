`define S0_RESET 4'd0
`define S1_OFFSET_IDLE 4'd1
`define S2_READ_P1 4'd2
`define S3_WRITE_P1 4'd3
`define S4_WRITE_P2 4'd4
`define S5_PRE_RESET_IDLE 4'd5

module wordcopy(input logic clk, input logic rst_n,
                // slave (CPU-facing)
                output logic slave_waitrequest, // assert if busy waiting for some internal process to be done
                input logic [3:0] slave_address, // address from CPU MASTER
                input logic slave_read, // enabled if CPU MASTER wants to read
                output logic [31:0] slave_readdata, // output to CPU MASTER what we just read
                input logic slave_write,  // enabled if CPU MASTER wants to write
                input logic [31:0] slave_writedata, // input from CPU MASTER what we want to write 
                // master (SDRAM-facing)
                input logic master_waitrequest, // from SDRAM_Controller to see if its busy
                output logic [31:0] master_address, // output to SDRAM SLAVE the address we want to access
                output logic master_read, // output if we want to read to the SDRAM SLAVE
                input logic [31:0] master_readdata,  // input from SDRAM SLAVE once we're done read_data
                input logic master_readdatavalid, // INPUT FROM SDRAM SLAVE if read_data is valid 
                output logic master_write, // output to SDRAM SLAVE if we want to write
                output logic [31:0] master_writedata); // output to SDRAM SLAVE of what we want to write
    // your code here
    
    // variable for holding the copied value
    logic [31:0] word_to_copy;
    
    // holder variables for the start address, destination address, and number of words
    logic [31:0] destination_addr, source_addr, number_of_words;
    logic [31:0] inc_destination_addr, inc_source_addr;

    // control for destination and source register
    logic address_count;
    logic address_reset;
    logic assign_destination, assign_source;
    always@(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0) // asyn reset
                begin
                    destination_addr = 32'b0;
                    source_addr = 32'b0;
                    inc_destination_addr = 32'b0;
                    inc_source_addr = 32'b0;
                end
            else if (assign_destination == 1'b1) // want to assign the destination holder
                begin
                    destination_addr = slave_writedata;
                    source_addr = source_addr;
                    inc_destination_addr = slave_writedata;
                    inc_source_addr = source_addr;
                    
                end
            
            else if (assign_source) // want to assign the source holder
                begin
                    destination_addr = destination_addr;
                    source_addr = slave_writedata;
                    inc_destination_addr = destination_addr;
                    inc_source_addr = slave_writedata;
                end

            else if (address_reset == 1'b1) // want to reset the addresses without universal async reset
                begin
                    destination_addr = destination_addr;
                    source_addr = source_addr;
                    inc_destination_addr = destination_addr;
                    inc_source_addr = source_addr;
                end

            else if (address_count == 1'b1) // wanna increment the addresses
                begin
                    inc_destination_addr = inc_destination_addr + 32'd4;
                    inc_source_addr = inc_source_addr + 32'd4;
                    destination_addr = destination_addr;
                    source_addr = source_addr;
                end

            else
                begin
                    destination_addr <= destination_addr;
                    source_addr <= source_addr;
                    inc_destination_addr <= inc_destination_addr;
                    inc_source_addr <= inc_source_addr;
                end
        end
    
    // control for number of words
    logic assign_number, number_reset;
    always @(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0) // universal async reset
                number_of_words = 32'd0;

            else if (assign_number == 1'b1) // assign number of words when offset 3 is presented 
                number_of_words = slave_writedata;

            else if (number_reset == 1'b1) // want to reset without universal asyn reset
                number_of_words = 32'd0;

            else
                number_of_words = number_of_words;
        end
    

    // word count variables
    logic word_count_finished;
    logic word_count_up;
    logic word_count_reset;
    logic [31:0] word_current_count;
    assign word_count_finished = (word_current_count == number_of_words - 32'd1) ? 1'b1 : 1'b0;
    always@(posedge clk or negedge rst_n)
    begin
        if (rst_n == 1'b0) // universal async reset
            word_current_count <= 32'b0;

        else if (word_count_up == 1'b1) // count up 
            word_current_count <= word_current_count + 1;

        else if (word_count_reset == 1'b1) // want to reset without universal async reset
            word_current_count <= 32'd0;

        else
            word_current_count <= word_current_count;
    end



    wire [3:0] present_state;
    logic [3:0] next_state;
    vDFF_async #4 STATE(clk, rst_n, next_state, `S0_RESET, present_state);
    

    always@(*)
    begin
        case (present_state)
            `S0_RESET: next_state = `S1_OFFSET_IDLE;
            `S1_OFFSET_IDLE:    
                begin
                    if ( (slave_address[1:0] == 2'b0)&&(slave_write == 1'b1) ) // if CPU writes into offset 0, we begin, considering it would go offset 1, 2, and 3 first
                        next_state = `S2_READ_P1;
                    else
                        next_state = `S1_OFFSET_IDLE;
                end
            `S2_READ_P1:
                begin
                    /*
                        wait_request = 0 , readdata_valid = 0
                            ... send address we want to read from 
                        wait_request = 1, readdata_valid = 0
                            ... some time after
                        wait_request = 0, readdata_valid = 1
                            ... now data is ready and we can go on to writing it,

                    */
                    if ( (master_waitrequest == 1'b1) || (master_readdatavalid == 1'b0) ) // we should stay if we are waiting to use SDRAM or even after we use it the value returned isnt valid yet
                        next_state = `S2_READ_P1;
                    else
                        next_state = `S3_WRITE_P1; 
                end
            `S3_WRITE_P1:
                begin
                    if (master_waitrequest == 1'b1)
                        next_state = `S3_WRITE_P1;
                    else
                        next_state = `S4_WRITE_P2;
                end
            `S4_WRITE_P2:
                begin
                    if (word_count_finished == 1'b1)
                        next_state = `S5_PRE_RESET_IDLE;
                    else
                        next_state = `S2_READ_P1;
                end
            `S5_PRE_RESET_IDLE:
                begin
                    if ( (slave_address[1:0] == 2'b0) && (slave_read == 1'b1) )
                        next_state = `S1_OFFSET_IDLE;
                    else
                        next_state = `S5_PRE_RESET_IDLE;
                end
            default: next_state = 4'bx;
        endcase
    end

    always_ff@(*)
    begin
        case(present_state)
            `S0_RESET:
                begin
                    address_count = 1'bx;
                    address_reset = 1'bx;
                    assign_destination = 1'bx;
                    assign_source = 1'bx;
                    assign_number = 1'bx;
                    number_reset = 1'bx;
                    word_count_reset = 1'bx;
                    word_count_up = 1'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    word_to_copy = 32'bx;

                    slave_readdata = 32'bx;
                    slave_waitrequest = 1'b0; // IMPORTANT
                end
            `S1_OFFSET_IDLE:
                begin
                    case(slave_address[1:0])
                        2'b00:
                            begin
                                assign_destination = 1'b0;
                                assign_source = 1'b0;
                                assign_number = 1'b0;
                            end
                        2'b01:
                            begin
                                assign_destination = 1'b1; // offset 1 means destination address is provided
                                assign_source = 1'b0;
                                assign_number = 1'b0;
                            end
                        2'b10:
                            begin
                                assign_destination = 1'b0;
                                assign_source = 1'b1; // offset 2 means source address is provided
                                assign_number = 1'b0;
                            end
                        2'b11:
                            begin
                                assign_destination = 1'b0;
                                assign_source = 1'b0;
                                assign_number = 1'b1; // offset 3 means slave address is provided
                            end
                        default:
                            begin
                                assign_destination = 1'b0;
                                assign_number = 1'b0;
                                assign_source = 1'b0;
                            end
                    endcase

                    address_count = 1'b0;
                    address_reset = 1'b0;
                    number_reset = 1'b0;
                    word_count_up = 1'b0;
                    word_count_reset = 1'b0;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    word_to_copy = word_to_copy;

                    slave_readdata = 32'bx;
                    slave_waitrequest = 1'b0; // IMPORTANT
                end
            `S2_READ_P1:
                begin
                    if (master_waitrequest == 1'b1) // we dont want to provide the ram anything until its ready to 
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;
                            word_to_copy = word_to_copy;
                        end
                    else if (master_readdatavalid == 1'b0) // if the wait request is off and there isnt a valid output, provide the source address and read enable signals
                        begin
                            master_address = inc_source_addr;
                            master_read = 1'b1;
                            master_write = 1'b0;
                            master_writedata = 32'bx;
                            word_to_copy = word_to_copy;
                        end
                    else    // meaning the wait request is off and there is a valid output indicating the the data we want is now at the output of the SDRAM and we can assign it 
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;
                            word_to_copy = master_readdata;
                        end
                    
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_destination = 1'b0;
                    assign_source = 1'b0;
                    assign_number = 1'b0;
                    number_reset = 1'b0;
                    word_count_up = 1'b0;
                    word_count_reset = 1'b0;

                    slave_readdata = 32'bx;
                    slave_waitrequest = 1'b1; // IMPORTANT             
                end
            `S3_WRITE_P1:
                begin
                    if (master_waitrequest == 1'b1)
                        begin
                            master_address = 32'bx;
                            master_write = 1'bx;
                            master_read = 1'bx;
                            master_writedata = 32'bx;                     
                        end
                    
                    else
                        begin
                            master_address = inc_destination_addr;
                            master_write = 1'b1;
                            master_writedata = word_to_copy;
                            master_read = 1'b0;
                            
                        end
                    /*
                    else 
                        begin
                            master_address = destination_addr;
                            master_write = 1'b1;
                            master_writedata = word_to_copy;
                            master_read = 1'b0;
                        end
                    
                    if (word_count_finished == 1'b0)
                        begin
                            address_count = 1'b1;
                            address_reset = 1'b0;
                            word_count_up = 1'b1;
                            word_count_reset  = 1'b0;
                        end
                    else
                        begin
                            address_count = 1'b1;
                            address_reset = 1'b0;
                            word_count_up = 1'b0;
                            word_count_reset = 1'b1;
                        end
                    */

                    address_count = 1'b0;
                    address_reset = 1'b0;
                    word_count_up = 1'b0;
                    word_count_reset = 1'b0;

                    assign_destination = 1'b0;
                    assign_source = 1'b0;
                    assign_number = 1'b0;
                    number_reset = 1'b0;
                    word_to_copy = word_to_copy;

                    slave_readdata = 32'bx;
                    slave_waitrequest = 1'b1; // IMPORTANT  
                    
                end
            `S4_WRITE_P2:
                begin
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    word_to_copy = word_to_copy;

                    assign_destination = 1'b0;
                    assign_source = 1'b0;
                    assign_number = 1'b0;
                    number_reset = 1'b0;

                    slave_readdata = 32'bx;
                    slave_waitrequest = 1'b1; // IMPORTANT 

                    if (word_count_finished == 1'b0)
                        begin
                            address_count = 1'b1;
                            address_reset = 1'b0;
                            word_count_up = 1'b1;
                            word_count_reset  = 1'b0;
                        end
                    else
                        begin
                            address_count = 1'b1;
                            address_reset = 1'b0;
                            word_count_up = 1'b0;
                            word_count_reset = 1'b1;
                        end
                end
            `S5_PRE_RESET_IDLE:
                begin
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    word_to_copy = word_to_copy;

                    address_reset = 1'b1;
                    address_count = 1'b0;
                    assign_destination = 1'b0;
                    assign_source = 1'b0;
                    assign_number = 1'b0;
                    number_reset = 1'b1;

                    word_count_up = 1'b0;
                    word_count_reset = 1'b1;

                    slave_readdata = 32'bx;
                    slave_waitrequest = 1'b0; // IMPORTANT  DONE 
                end
            
            default:
                begin
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    word_to_copy = 32'bx;

                    address_reset = 1'bx;
                    address_count = 1'bx;
                    assign_destination = 1'bx;
                    assign_source = 1'bx;
                    assign_number = 1'bx;
                    number_reset = 1'bx;

                    word_count_up = 1'bx;
                    word_count_reset = 1'bx;

                    slave_readdata = 32'bx;
                    slave_waitrequest = 1'bx; // IMPORTANT  DONE 
                end
        endcase
    end



endmodule: wordcopy

module vDFF_async (clk, reset, in, reset_in, out);
     parameter n = 1;
     input clk, reset;
     input [n-1:0] in, reset_in;
     output reg [n-1:0] out;

     always@(posedge clk or negedge reset)
     begin
          if (reset == 1'b0)
               out = reset_in;
          else
               out = in;
     end
endmodule
