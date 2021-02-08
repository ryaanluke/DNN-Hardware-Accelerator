`timescale 1ps / 1ps

module tb_rtl_dnn();

logic clock, reset;

logic [3:0] slave_address;
logic slave_read, slave_write;
logic [31:0] slave_writedata;

logic master_waitrequest;
logic [31:0] master_readdata;
logic master_readdatavalid;

logic [3:0] slave_waitrequest;
logic [31:0] slave_readdata;
logic [31:0] master_address;
logic master_read;
logic master_write;
logic [31:0] master_writedata;

dnn DUT(clock, reset, slave_waitrequest, slave_address, slave_read,
             slave_readdata, slave_write, slave_writedata, master_waitrequest,
             master_address, master_read, master_readdata, master_readdatavalid,
             master_write, master_writedata);
             
initial begin
    clock = 1'b0;
    forever #5 clock = ~clock;
end

initial begin
    #10
    reset = 1'b1;
    #10
    reset = 1'b0;
    #10
    reset = 1'b1;
    #10
    

    $display("-- CHECKING RESET STATE --");
    assert(DUT.present_state == 5'd1) $display("EXPECTED STATE = STATE 0");
    else $display("UNEXPECTED STATE");
    $display(" ");

    slave_write = 1'b1;
    slave_address = 4'b0001;
    slave_writedata = 32'd400000; // bias

    #10
    slave_write = 1'b1;
    slave_address = 4'b0010;
    slave_writedata = 32'd10; // weight

    #10
    slave_write = 1'b1;
    slave_address = 4'b0011;
    slave_writedata = 32'd2020; // input actv

    #10
    slave_write = 1'b1;
    slave_address = 4'b0100;
    slave_writedata = 32'd3030; // output act

    #10
    slave_write = 1'b1;
    slave_address = 4'b0101;
    slave_writedata = 32'd1; // vector length

    #10
    slave_write = 1'b1;
    slave_address = 5'b0111;
    slave_writedata = 32'd1; // ReLU

    #10
    $display("-- CHECKING PROPER OFFSET VALUES --");
    assert(DUT.current_bias_vector_addr == 32'd400000) $display("EXPECTED BIAS VECTOR ADDRESS = 400000");
    else $display("UNEXPECTED BIAS VECTOR ADDRESS");

    assert(DUT.current_weight_vector_addr == 32'd10) $display("EXPECTED WEIGHT VECTOR ADDRESS = 10");
    else $display("UNEXPECTED WEIGHT VECTOR ADDRESS");

    assert(DUT.current_activation_vector_addr == 32'd2020) $display("EXPECTED ACTIVATION VECTOR ADDRESS = 2020");
    else $display("UNEXPECTED ACTIVATION VECTOR ADDRESS");

    assert(DUT.current_output_activation_vector_addr == 32'd3030) $display("EXPECTED OUTPUT ACTIVATION VECTOR ADDRESS = 3030");
    else $display("UNEXPECTED OUTPUT ACTIVATION VECTOR ADDRESS");

    assert(DUT.vector_length == 32'd1) $display("EXPECTED VECTOR LENGTH = 1");
    else $display("UNEXPECTED VECTOR LENGTH");

    assert(DUT.relu_or_norelu == 32'd1) $display("EXPECTED ReLU = 1");
    else $display("UNEXPECTED ReLU");
    $display(" ");

    slave_write = 1'b1;
    slave_read = 1'b0;
    slave_address = 4'b0000;
    slave_writedata = 32'd1010;

    #5
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 2 - SDRAM NOT READY --");
    assert(DUT.present_state == 5'd2) $display("EXPECTED STATE = STATE 2");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd2) $display("EXPECTED NEXT STATE = STATE 2");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;

    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 2 - SDRAM READY --");
    assert(DUT.present_state == 5'd2) $display("EXPECTED STATE = STATE 2");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd3) $display("EXPECTED NEXT STATE = STATE 3");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_address == 32'd400000) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 3 - SDRAM READING --");
    assert(DUT.present_state == 5'd3) $display("EXPECTED STATE = STATE 3");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd3) $display("EXPECTED NEXT STATE = STATE 3");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_address == 32'd400000) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b1;
    master_readdata = 32'd100;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 3 - SDRAM READ DONE --");
    assert(DUT.present_state == 5'd3) $display("EXPECTED STATE = STATE 3");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd4) $display("EXPECTED NEXT STATE = STATE 4");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.bias_element == 32'd100) $display ("EXPECTED BIAS ELEMENT COPIED");
    else $display("UNEXPECTED BIAS ELEMENT COPIED");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 4 - SDRAM NOT READY --");
    assert(DUT.present_state == 5'd4) $display("EXPECTED STATE = STATE 4");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd4) $display("EXPECTED NEXT STATE = STATE 4");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 4 - SDRAM READY --");
    assert(DUT.present_state == 5'd4) $display("EXPECTED STATE = STATE 4");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd5) $display("EXPECTED NEXT STATE = STATE 5");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd10) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 5 - SDRAM READING --");
    assert(DUT.present_state == 5'd5) $display("EXPECTED STATE = STATE 5");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd5) $display("EXPECTED NEXT STATE = STATE 5");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd10) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b1;
    master_readdata = 32'd200;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 5 - SDRAM READ DONE --");
    assert(DUT.present_state == 5'd5) $display("EXPECTED STATE = STATE 5");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd6) $display("EXPECTED NEXT STATE = STATE 6");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.weight_element == 32'd200) $display ("EXPECTED WEIGHT ELEMENT COPIED");
    else $display("UNEXPECTED WEIGHT ELEMENT COPIED");
    $display(" ");

    //

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 6 - SDRAM NOT READY --");
    assert(DUT.present_state == 5'd6) $display("EXPECTED STATE = STATE 6");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd6) $display("EXPECTED NEXT STATE = STATE 6");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 6 - SDRAM READY --");
    assert(DUT.present_state == 5'd6) $display("EXPECTED STATE = STATE 6");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd7) $display("EXPECTED NEXT STATE = STATE 7");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd2020) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 7 - SDRAM READING --");
    assert(DUT.present_state == 5'd7) $display("EXPECTED STATE = STATE 7");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd7) $display("EXPECTED NEXT STATE = STATE 7");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd2020) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b1;
    master_readdata = 32'h20C5;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 7 - SDRAM READ DONE --");
    assert(DUT.present_state == 5'd7) $display("EXPECTED STATE = STATE 7");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd8) $display("EXPECTED NEXT STATE = STATE 8");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.activation_element == 32'd300) $display ("EXPECTED ACTIVATION ELEMENT COPIED");
    else $display("UNEXPECTED ACTIVATION ELEMENT COPIED");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    //

    
    // NOTE: THIS IS THE PART I TEST THE MATH, BUT FOR RIGHT NOW WE WILL JUST SKIP THREE CLOCK CYCLES AND SEE IF THE STUFF AFTER THE MATH IS DONE IS FINE
    #10
    #10
    #10
    #10
    #10
    #10
    // CLOCK CYCLES NOT ACCURATE, LETS JUST SAY AFTER THE MATH THE SDRAM IS STILL NOT READY TO WRITE

    //

    
    $display("-- CHECKING FIRST STAY AT STATE 11 - SDRAM NOT READY --");
    assert(DUT.present_state == 5'd11) $display("EXPECTED STATE = STATE 11");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd11) $display("EXPECTED NEXT STATE = STATE 11");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 11 - SDRAM READY --");
    assert(DUT.present_state == 5'd11) $display("EXPECTED STATE = STATE 11");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd12) $display("EXPECTED NEXT STATE = STATE 12");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b1) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd3030) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b0) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    // assert (DUT.master_writedata == ????) $display("EXPECTED MASTER WRITE DATA SENT");
    // else $display("UNEXPECTED MASTER WRITE DATA SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 12 - SDRAM WRITING --");
    assert(DUT.present_state == 5'd12) $display("EXPECTED STATE = STATE 12");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd12) $display("EXPECTED NEXT STATE = STATE 12");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b1) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd3030) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b0) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 12 - SDRAM WRITE DONE --");
    assert(DUT.present_state == 5'd12) $display("EXPECTED STATE = STATE 12");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd13) $display("EXPECTED NEXT STATE = STATE 13");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.address_count == 1'b0) $display("EXPECTED ADDRESS COUNT SIGNAL SENT");
    else $display ("UNEXPECTED ADDRESS COUNT SIGNAL");

    assert (DUT.address_reset == 1'b1) $display("EXPECTED ADDRESS RESET SIGNAL SENT");
    else $display ("UNEXPECTED ADDRESS RESET SIGNAL");

    assert (DUT.element_count_up == 1'b0) $display("EXPECTED ELEMENT COUNT SIGNAL SENT");
    else $display ("UNEXPECTED ELEMENT COUNT SIGNAL");

    assert (DUT.element_count_reset == 1'b1) $display("EXPECTED ELEMENT COUNT RESET SIGNAL SENT");
    else $display ("UNEXPECTED ELEMENT COUNT RESET SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 13 - DNN DONE --");
    assert(DUT.present_state == 5'd13) $display("EXPECTED STATE = STATE 6");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd1) $display("EXPECTED NEXT STATE = STATE 1");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b0) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    #10
    $display("-- CHECKING DNN DONE --");
    assert(DUT.present_state == 5'd1) $display("EXPECTED STATE = STATE 1");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd1) $display("EXPECTED NEXT STATE = STATE 1");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b0) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b0;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;
    //
    //
    //
    //
    //
    //
    //
    #95
    $display("---------------------------------------------------");

    slave_write = 1'b1;
    slave_address = 4'b0001;
    slave_writedata = 32'd400000; // bias

    #10
    slave_write = 1'b1;
    slave_address = 4'b0010;
    slave_writedata = 32'd10; // weight

    #10
    slave_write = 1'b1;
    slave_address = 4'b0011;
    slave_writedata = 32'd2020; // input actv

    #10
    slave_write = 1'b1;
    slave_address = 4'b0100;
    slave_writedata = 32'd3030; // output act

    #10
    slave_write = 1'b1;
    slave_address = 4'b0101;
    slave_writedata = 32'd1; // vector length

    #10
    slave_write = 1'b1;
    slave_address = 5'b0111;
    slave_writedata = 32'd1; // ReLU

    #10
    $display("-- CHECKING PROPER OFFSET VALUES --");
    assert(DUT.current_bias_vector_addr == 32'd400000) $display("EXPECTED BIAS VECTOR ADDRESS = 400000");
    else $display("UNEXPECTED BIAS VECTOR ADDRESS");

    assert(DUT.current_weight_vector_addr == 32'd10) $display("EXPECTED WEIGHT VECTOR ADDRESS = 10");
    else $display("UNEXPECTED WEIGHT VECTOR ADDRESS");

    assert(DUT.current_activation_vector_addr == 32'd2020) $display("EXPECTED ACTIVATION VECTOR ADDRESS = 2020");
    else $display("UNEXPECTED ACTIVATION VECTOR ADDRESS");

    assert(DUT.current_output_activation_vector_addr == 32'd3030) $display("EXPECTED OUTPUT ACTIVATION VECTOR ADDRESS = 3030");
    else $display("UNEXPECTED OUTPUT ACTIVATION VECTOR ADDRESS");

    assert(DUT.vector_length == 32'd1) $display("EXPECTED VECTOR LENGTH = 1");
    else $display("UNEXPECTED VECTOR LENGTH");

    assert(DUT.relu_or_norelu == 32'd1) $display("EXPECTED ReLU = 1");
    else $display("UNEXPECTED ReLU");
    $display(" ");

    slave_write = 1'b1;
    slave_read = 1'b0;
    slave_address = 4'b0000;
    slave_writedata = 32'd1010;

    #5
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 2 - SDRAM NOT READY --");
    assert(DUT.present_state == 5'd2) $display("EXPECTED STATE = STATE 2");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd2) $display("EXPECTED NEXT STATE = STATE 2");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;

    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 2 - SDRAM READY --");
    assert(DUT.present_state == 5'd2) $display("EXPECTED STATE = STATE 2");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd3) $display("EXPECTED NEXT STATE = STATE 3");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_address == 32'd400000) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 3 - SDRAM READING --");
    assert(DUT.present_state == 5'd3) $display("EXPECTED STATE = STATE 3");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd3) $display("EXPECTED NEXT STATE = STATE 3");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_address == 32'd400000) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b1;
    master_readdata = 32'h251f;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 3 - SDRAM READ DONE --");
    assert(DUT.present_state == 5'd3) $display("EXPECTED STATE = STATE 3");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd4) $display("EXPECTED NEXT STATE = STATE 4");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.bias_element == 32'd100) $display ("EXPECTED BIAS ELEMENT COPIED");
    else $display("UNEXPECTED BIAS ELEMENT COPIED");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 4 - SDRAM NOT READY --");
    assert(DUT.present_state == 5'd4) $display("EXPECTED STATE = STATE 4");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd4) $display("EXPECTED NEXT STATE = STATE 4");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 4 - SDRAM READY --");
    assert(DUT.present_state == 5'd4) $display("EXPECTED STATE = STATE 4");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd5) $display("EXPECTED NEXT STATE = STATE 5");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd10) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 5 - SDRAM READING --");
    assert(DUT.present_state == 5'd5) $display("EXPECTED STATE = STATE 5");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd5) $display("EXPECTED NEXT STATE = STATE 5");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b0) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd10) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b1) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b1;
    master_readdata = 32'd200;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 5 - SDRAM READ DONE --");
    assert(DUT.present_state == 5'd5) $display("EXPECTED STATE = STATE 5");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd6) $display("EXPECTED NEXT STATE = STATE 6");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.weight_element == 32'd200) $display ("EXPECTED WEIGHT ELEMENT COPIED");
    else $display("UNEXPECTED WEIGHT ELEMENT COPIED");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 6 - CACHE READY --");
    assert(DUT.present_state == 5'd6) $display("EXPECTED STATE = STATE 6");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd7) $display("EXPECTED NEXT STATE = STATE 7");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.cache_address == 10'b0) $display("EXPECTED CACHE ADDRESS SENT");
    else $display("UNEXPECTED CACHE ADDRESS");

    assert (DUT.cache_wren == 1'b0) $display("EXPECTED CACHE READ SENT");
    else $display("UNEXPECTED CACHE READ");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'bx;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 7 - CACHE READ DONE --");
    assert(DUT.present_state == 5'd7) $display("EXPECTED STATE = STATE 7");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd8) $display("EXPECTED NEXT STATE = STATE 8");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.activation_element == 32'd300) $display ("EXPECTED ACTIVATION ELEMENT COPIED");
    else $display("UNEXPECTED ACTIVATION ELEMENT COPIED");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    //

    // NOTE: THIS IS THE PART I TEST THE MATH, BUT FOR RIGHT NOW WE WILL JUST SKIP THREE CLOCK CYCLES AND SEE IF THE STUFF AFTER THE MATH IS DONE IS FINE
    #10
    #10
    #10
    #10
    #10
    #10
    // CLOCK CYCLES NOT ACCURATE, LETS JUST SAY AFTER THE MATH THE SDRAM IS STILL NOT READY TO WRITE

    //

    $display("-- CHECKING FIRST STAY AT STATE 11 - SDRAM NOT READY --");
    assert(DUT.present_state == 5'd11) $display("EXPECTED STATE = STATE 11");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd11) $display("EXPECTED NEXT STATE = STATE 11");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 11 - SDRAM READY --");
    assert(DUT.present_state == 5'd11) $display("EXPECTED STATE = STATE 11");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd12) $display("EXPECTED NEXT STATE = STATE 12");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b1) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd3030) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b0) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    // assert (DUT.master_writedata == ????) $display("EXPECTED MASTER WRITE DATA SENT");
    // else $display("UNEXPECTED MASTER WRITE DATA SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 12 - SDRAM WRITING --");
    assert(DUT.present_state == 5'd12) $display("EXPECTED STATE = STATE 12");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd12) $display("EXPECTED NEXT STATE = STATE 12");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b1) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd3030) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b0) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 12 - SDRAM WRITE DONE --");
    assert(DUT.present_state == 5'd12) $display("EXPECTED STATE = STATE 12");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd13) $display("EXPECTED NEXT STATE = STATE 13");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.address_count == 1'b0) $display("EXPECTED ADDRESS COUNT SIGNAL SENT");
    else $display ("UNEXPECTED ADDRESS COUNT SIGNAL");

    assert (DUT.address_reset == 1'b1) $display("EXPECTED ADDRESS RESET SIGNAL SENT");
    else $display ("UNEXPECTED ADDRESS RESET SIGNAL");

    assert (DUT.element_count_up == 1'b0) $display("EXPECTED ELEMENT COUNT SIGNAL SENT");
    else $display ("UNEXPECTED ELEMENT COUNT SIGNAL");

    assert (DUT.element_count_reset == 1'b1) $display("EXPECTED ELEMENT COUNT RESET SIGNAL SENT");
    else $display ("UNEXPECTED ELEMENT COUNT RESET SIGNAL");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 13 - DNN DONE --");
    assert(DUT.present_state == 5'd13) $display("EXPECTED STATE = STATE 6");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd1) $display("EXPECTED NEXT STATE = STATE 1");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b0) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    #10
    $display("-- CHECKING DNN DONE --");
    assert(DUT.present_state == 5'd1) $display("EXPECTED STATE = STATE 1");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 5'd1) $display("EXPECTED NEXT STATE = STATE 1");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b0) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");
    
    

    
    

    
    $stop;
end

endmodule: tb_rtl_dnn
