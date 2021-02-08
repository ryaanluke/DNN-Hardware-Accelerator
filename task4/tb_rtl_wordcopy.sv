module tb_rtl_wordcopy();

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

wordcopy DUT(clock, reset, slave_waitrequest, slave_address, slave_read,
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
    assert(DUT.present_state == 4'd1) $display("EXPECTED STATE = STATE 0");
    else $display("UNEXPECTED STATE");
    $display(" ");

    slave_write = 1'b1;
    slave_address = 4'b0001;
    slave_writedata = 32'd400000;

    #10
    slave_write = 1'b1;
    slave_address = 4'b0010;
    slave_writedata = 32'd10;

    #10
    slave_write = 1'b1;
    slave_address = 4'b0011;
    slave_writedata = 32'd1;

    #10
    $display("-- CHECKING PROPER OFFSET VALUES --");
    assert(DUT.destination_addr == 32'd400000) $display("EXPECTED DESTINATION ADDRESS = 400000");
    else $display("UNEXPECTED DESTINATION ADDRESS");

    assert(DUT.source_addr == 32'd10) $display("EXPECTED SOURCE ADDRESS = 10");
    else $display("UNEXPECTED SOURCE ADDRESS");

    assert(DUT.number_of_words == 32'd1) $display("EXPECTED NUMBER OF WORDS = 1");
    else $display("UNEXPECTED NUMBER OF WORDS");

    assert (slave_waitrequest == 1'b0) $display("SLAVE WAIT REQUEST 0 : READY TO START");
    else $display("WRONG SLAVE WAIT REQUEST");

    assert(DUT.present_state == 4'd1) $display("EXPECTED STATE = STATE 1");
    else $display("UNEXPECTED STATE");
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
    assert(DUT.present_state == 4'd2) $display("EXPECTED STATE = STATE 2");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd2) $display("EXPECTED NEXT STATE = STATE 2");
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
    assert(DUT.present_state == 4'd2) $display("EXPECTED STATE = STATE 2");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd3) $display("EXPECTED NEXT STATE = STATE 3");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_address == 32'd10) $display("EXPECTED MASTER ADDRESS SENT");
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
    assert(DUT.present_state == 4'd3) $display("EXPECTED STATE = STATE 3");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd3) $display("EXPECTED NEXT STATE = STATE 3");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL");
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    
    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b1;
    master_readdata = 32'd100;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 3 - SDRAM READ DONE --");
    assert(DUT.present_state == 4'd3) $display("EXPECTED STATE = STATE 3");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd4) $display("EXPECTED NEXT STATE = STATE 4");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.word_to_copy == 32'd100) $display ("EXPECTED WORD COPIED");
    else $display("UNEXPECTED WORD COPIED");
    $display(" ");

    
    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;
    

    #10
    $display("-- CHECKING FIRST STAY AT STATE 4 - SDRAM NOT READY --");
    assert(DUT.present_state == 4'd4) $display("EXPECTED STATE = STATE 4");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd4) $display("EXPECTED NEXT STATE = STATE 4");
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
    assert(DUT.present_state == 4'd4) $display("EXPECTED STATE = STATE 4");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd5) $display("EXPECTED NEXT STATE = STATE 5");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b1) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd400000) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b0) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    assert (DUT.master_writedata == 32'd100) $display("EXPECTED MASTER WRITE DATA SENT");
    else $display("UNEXPECTED MASTER WRITE DATA SENT");
    $display(" ");

    
    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 5 - COPIED WORD JUST SENT - STILL PROCESSING --");
    assert(DUT.present_state == 4'd5) $display("EXPECTED STATE = STATE 5");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd5) $display("EXPECTED NEXT STATE = STATE 5");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.master_write == 1'b1) $display("EXPECTED MASTER WRITE SENT");
    else $display("UNEXPECTED MASTER WRITE SENT");

    assert (DUT.master_address == 32'd400000) $display("EXPECTED MASTER ADDRESS SENT");
    else $display("UNEXPECTED MASTER ADDRESS SENT");

    assert (DUT.master_read == 1'b0) $display("EXPECTED MASTER READ SENT");
    else $display("UNEXPECTED MASTER READ SENT");

    assert (DUT.master_writedata == 32'd100) $display("EXPECTED MASTER WRITE DATA SENT");
    else $display("UNEXPECTED MASTER WRITE DATA SENT");
    $display(" ");

    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b0;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING SECOND STAY AT STATE 5 - COPIED WORD SENT DONE PROCESSING --");
    assert(DUT.present_state == 4'd5) $display("EXPECTED STATE = STATE 5");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd6) $display("EXPECTED NEXT STATE = STATE 5");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b1) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");

    assert (DUT.word_count_finished == 1'b1) $display("EXPECTED WORD COUNT FINISHED") ;
    else $display("UNEXPECTED WORD COUNT FINISHED");

    assert (DUT.address_count == 1'b0) $display("EXPECTED ADDRESS COUNT SIGNAL") ;
    else $display("UNEXPECTED ADDRESS COUNT SIGNAL");

    assert (DUT.address_reset == 1'b1) $display("EXPECTED ADDRESS RESET SIGNAL") ;
    else $display("UNEXPECTED ADDRESS RESET SIGNAL");

    assert (DUT.word_count_up == 1'b0) $display("EXPECTED WORD COUNT SIGNAL") ;
    else $display("UNEXPECTED WORD COUNT SIGNAL");

    assert (DUT.word_count_reset == 1'b1) $display("EXPECTED WORD COUNT RESET SIGNAL") ;
    else $display("UNEXPECTED WORD COUNT RESET SIGNAL");
    $display(" ");

    
    slave_write = 1'b0;
    slave_read = 1'b1;
    slave_address = 4'd0;
    master_waitrequest = 1'b1;
    master_readdatavalid = 1'b0;
    master_readdata = 32'bx;

    #10
    $display("-- CHECKING FIRST STAY AT STATE 6 - WORD COPY DONE --");
    assert(DUT.present_state == 4'd6) $display("EXPECTED STATE = STATE 6");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd1) $display("EXPECTED NEXT STATE = STATE 1");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b0) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    #10
    $display("-- CHECKING WORD COPY DONE --");
    assert(DUT.present_state == 4'd1) $display("EXPECTED STATE = STATE 1");
    else $display("UNEXPECTED STATE");

    assert (DUT.next_state == 4'd1) $display("EXPECTED NEXT STATE = STATE 1");
    else $display("UNEXPECTED NEXT STATE");

    assert (DUT.slave_waitrequest == 1'b0) $display("EXPECTED SLAVE WAIT REQUEST SIGNAL") ;
    else $display("UNEXPECTED SLAVE WAIT REQUEST SIGNAL");
    $display(" ");

    

    

    $stop;
end


endmodule: tb_rtl_wordcopy
