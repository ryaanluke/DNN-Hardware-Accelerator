`define RESET 5'd0
`define OFFSET_IDLE 5'd1 // wait for start
`define READ_BIAS_ADDR 5'd2 // send address
`define READ_BIAS_ADDR_2 5'd3 // recieve data : hold stable
`define READ_WEIGHT_ADDR 5'd4 // send addres
`define READ_WEIGHT_ADDR_2 5'd5 // recieve data : hold stable
`define READ_INPUT_ACTIVATION_ADDR 5'd6 // send address
`define READ_INPUT_ACTIVATION_ADDR_2 5'd7 // recieve data : hold stable
`define A_MULT_B 5'd8 // multiply 
`define APPLY_Q1616_PLUS_B 5'd9 // apply q1616
`define APPLY_RELU 5'd10 // apply relu
`define WRITE_OUTPUT_ACTIVATION_ADDR 5'd11 // send address
`define CHECK_VECTOR_LENGTH_DONE 5'd12 // hold stable : check iteration
`define PRE_CPU_READ_IDLE 5'd13 // end idle

`define ROUNDING_CORRECTION 16'h8000


module dnn(input logic clk, input logic rst_n,
           // slave (CPU-facing)
           output logic slave_waitrequest,
           input logic [3:0] slave_address,
           input logic slave_read, output logic [31:0] slave_readdata,
           input logic slave_write, input logic [31:0] slave_writedata,
           // master (SDRAM-facing)
           input logic master_waitrequest,
           output logic [31:0] master_address,
           output logic master_read, input logic [31:0] master_readdata, input logic master_readdatavalid,
           output logic master_write, output logic [31:0] master_writedata);

    // your code here

    /*
        CPU will write addresses of the bias vector, weight matrix, input and output activations, and the input
        activation length.

        word | meaning
        0 = when written, starts accelerator; may also be read
        1 = bias vector byte address
        2 = weight matrix byte address
        3 = input activation vector byte address
        4 = output activations vector byte address
        5 = input activations vector length
        6 = reserved
        7 = activation function: 1 if ReLU, 0 if identity
            - will write 1 if the ReLU activation function is to be used after the dot product, or 0 if no activation function
                is to be applied

        each layer computes: a' = ReLU(weight dot activation + bias) where ReLU maps all negative numbers to 0

        event flow:
            - wait until write into offset 0 to start compution, idle to extract info
            - once write starts:
                - get bias vector element
                - get weight vector element
                - get input activation vector element
                - multiply the numbers
                - apply Q16
                - check and apply or not apply ReLU
                - write into output
                - check if we dont vector length or not, repeat if not done
                - idle if we are done
        
        ReLu event flow: ReLU( ( (w*a) << 16) + b) 
            - so w*a
            - shift by 16
            - add 5
            - then apply ReLU
    */

    
    // for addresses
    logic [31:0] current_bias_vector_addr, current_weight_vector_addr, current_activation_vector_addr, current_output_activation_vector_addr;
    logic [31:0] inc_current_bias_vector_addr, inc_current_output_activation_vector_addr; // for outer loop
    logic [31:0] inc_inner_weight_vector, inc_inner_activation_vector; // for inner loop
    
    // for vector length
    logic signed [31:0] vector_length;

    // for counting elements
    logic signed [31:0] element_current_count, element_current_count_inner;

    // for getting relu or no relu
    logic [31:0] relu_or_norelu;

    // for holding current element
    logic signed [31:0] activation_element, bias_element, weight_element;

    // for calculating W*a, account for overflow
    logic signed [63:0] w_a;

    // for applying Q1616
    logic signed [31:0] Q1616_w_a_plus_b;
    
    // for applying ReLU
    logic signed [31:0] relu_Q1616_w_a_plus_b;

    // for controlling local cache in reuse implementation
    logic cache_valid;
    logic signed [31:0] previous_activation_vector_addr, previous_vector_length;
    logic [9:0] cache_address;
    logic [31:0] cache_writedata;
    logic cache_wren;
    logic [31:0] cache_readdata, cache_current_element;
    
    // our local cache
    task6_mem DNN_CACHE (cache_address, clk, cache_writedata, cache_wren, cache_readdata);

    // controlling address
    logic address_count;
    logic address_reset;
    logic assign_bias, assign_weight, assign_activation, assign_output_activation;
    logic inner_address_reset, inner_address_count;
    always@(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0)
                begin
                    current_activation_vector_addr = 32'b0;
                    current_bias_vector_addr = 32'b0;
                    current_output_activation_vector_addr = 32'b0;
                    current_weight_vector_addr = 32'b0;
                    
                    inc_current_bias_vector_addr = 32'b0;
                    inc_current_output_activation_vector_addr = 32'b0;

                    inc_inner_activation_vector = 32'b0;
                    inc_inner_weight_vector = 32'b0;
                end
            else if (assign_activation == 1'b1)
                begin
                    current_activation_vector_addr = slave_writedata;
                    inc_inner_activation_vector = slave_writedata;

                    current_bias_vector_addr = current_bias_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_bias_vector_addr = inc_current_bias_vector_addr;
                    inc_current_output_activation_vector_addr = inc_current_output_activation_vector_addr;

                    inc_inner_weight_vector = inc_inner_weight_vector;
                end
            else if (assign_bias == 1'b1)
                begin
                    current_bias_vector_addr = slave_writedata;
                    inc_current_bias_vector_addr = slave_writedata;

                    current_activation_vector_addr = current_activation_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_output_activation_vector_addr = inc_current_output_activation_vector_addr;

                    inc_inner_weight_vector = inc_inner_weight_vector;
                    inc_inner_activation_vector = inc_inner_activation_vector;
                end
            else if (assign_output_activation == 1'b1)
                begin
                    current_output_activation_vector_addr = slave_writedata;
                    inc_current_output_activation_vector_addr = slave_writedata;

                    current_activation_vector_addr = current_activation_vector_addr;
                    current_bias_vector_addr = current_bias_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_bias_vector_addr = inc_current_bias_vector_addr;


                    inc_inner_weight_vector = inc_inner_weight_vector;
                    inc_inner_activation_vector = inc_inner_activation_vector;
                end
            else if (assign_weight == 1'b1)
                begin
                    current_weight_vector_addr = slave_writedata;
                    inc_inner_weight_vector = slave_writedata;

                    current_activation_vector_addr = current_activation_vector_addr;
                    current_bias_vector_addr = current_bias_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;

                    inc_current_bias_vector_addr = inc_current_bias_vector_addr;
                    inc_current_output_activation_vector_addr = inc_current_output_activation_vector_addr;

                    inc_inner_activation_vector = inc_inner_activation_vector;
                end
            else if (address_reset == 1'b1)
                begin
                    current_activation_vector_addr = current_activation_vector_addr;
                    current_bias_vector_addr = current_bias_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_bias_vector_addr = current_bias_vector_addr;
                    inc_current_output_activation_vector_addr = current_output_activation_vector_addr;

                    inc_inner_weight_vector = current_weight_vector_addr;
                    inc_inner_activation_vector = current_activation_vector_addr;
                end
                
            else if (address_count == 1'b1)
                begin
                    current_activation_vector_addr = current_activation_vector_addr;
                    current_bias_vector_addr = current_bias_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_bias_vector_addr = inc_current_bias_vector_addr + 32'd4;
                    inc_current_output_activation_vector_addr = inc_current_output_activation_vector_addr + 32'd4;

                    inc_inner_weight_vector = inc_inner_weight_vector;
                    inc_inner_activation_vector = inc_inner_activation_vector;
                end

            else if (inner_address_count == 1'b1)
                begin
                    current_activation_vector_addr = current_activation_vector_addr;
                    current_bias_vector_addr = current_bias_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_bias_vector_addr = inc_current_bias_vector_addr;
                    inc_current_output_activation_vector_addr = inc_current_output_activation_vector_addr;

                    inc_inner_weight_vector = inc_inner_weight_vector + 32'd4;
                    inc_inner_activation_vector = inc_inner_activation_vector + 32'd4;
                end
            
            else if (inner_address_reset == 1'b1)
                begin
                    current_activation_vector_addr = current_activation_vector_addr;
                    current_bias_vector_addr = current_bias_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_bias_vector_addr = inc_current_bias_vector_addr;
                    inc_current_output_activation_vector_addr = inc_current_output_activation_vector_addr;

                    inc_inner_weight_vector = current_weight_vector_addr;
                    inc_inner_activation_vector = current_activation_vector_addr;
                end
            else
                begin
                    current_activation_vector_addr = current_activation_vector_addr;
                    current_bias_vector_addr = current_bias_vector_addr;
                    current_output_activation_vector_addr = current_output_activation_vector_addr;
                    current_weight_vector_addr = current_weight_vector_addr;

                    inc_current_bias_vector_addr = inc_current_bias_vector_addr;
                    inc_current_output_activation_vector_addr = inc_current_output_activation_vector_addr;

                    inc_inner_activation_vector = inc_inner_activation_vector;
                    inc_inner_weight_vector = inc_inner_weight_vector;
                end
        end
    
    // controlling vector length
    logic assign_vector_length, vector_length_reset;
    always @(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0)
                vector_length = 32'd0;

            else if (assign_vector_length == 1'b1)
                vector_length = slave_writedata;

            else if (vector_length_reset == 1'b1)
                vector_length = 32'd0;
            else
                vector_length = vector_length;
        end
    
    // controlling number of elements operated on, FOR OUTERLOOP
    logic element_count_finished, element_count_up, element_count_reset;
    assign element_count_finished = (element_current_count == vector_length - 32'd1) ? 1'b1 : 1'b0;
    always @(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0)
                element_current_count = 32'd0;

            else if (element_count_up == 1'b1)
                element_current_count = element_current_count + 1;
            
            else if (element_count_reset == 1'b1)
                element_current_count = 32'd0;
            
            else
                element_current_count = element_current_count;
        end
    
    // controlling number of elements operated on, FOR INNERLOOP
    logic element_count_finished_inner, element_count_up_inner, element_count_reset_inner;
    assign element_count_finished_inner = (element_current_count_inner == vector_length - 32'd1) ? 1'b1 : 1'b0;
    always @(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0)
                element_current_count_inner = 32'd0;

            else if (element_count_up_inner == 1'b1)
                element_current_count_inner = element_current_count_inner + 1;
            
            else if (element_count_reset_inner == 1'b1)
                element_current_count_inner = 32'd0;
            
            else
                element_current_count_inner = element_current_count_inner;
        end
    
    // controlling relu_or_norelu
    logic assign_relu_or_norelu, relu_or_norelu_reset;
    always @(posedge clk or negedge rst_n)
        begin
            if (rst_n == 1'b0)
                relu_or_norelu = 32'dx;

            else if (assign_relu_or_norelu == 1'b1)
                relu_or_norelu = slave_writedata;

            else if (relu_or_norelu_reset == 1'b1)
                relu_or_norelu = 32'dx;

            else
                relu_or_norelu = relu_or_norelu;
        end
    



    wire [4:0] present_state;
    logic [4:0] next_state;
    vDFF_async #5 STATE(clk, rst_n, next_state, `RESET, present_state);

    always@(*)
        begin
            case (present_state)
                `RESET: next_state = `OFFSET_IDLE;
                `OFFSET_IDLE:
                    begin
                        if ( (slave_address  == 4'b0) && (slave_write === 1'b1) )
                            next_state = `READ_BIAS_ADDR;
                        else
                            next_state = `OFFSET_IDLE;
                    end
                `READ_BIAS_ADDR:
                    begin
                        if ( master_waitrequest == 1'b1 )
                            next_state = `READ_BIAS_ADDR;
                        else
                            next_state = `READ_BIAS_ADDR_2;
                    end
                `READ_BIAS_ADDR_2:
                    begin
                        if ( (master_waitrequest == 1'b0) && (master_readdatavalid == 1'b1) )
                            next_state = `READ_WEIGHT_ADDR;
                        else
                            next_state = `READ_BIAS_ADDR_2;
                    end
                `READ_WEIGHT_ADDR:
                    begin
                        if ( master_waitrequest == 1'b1 )
                            next_state = `READ_WEIGHT_ADDR;
                        else
                            next_state = `READ_WEIGHT_ADDR_2;
                    end
                `READ_WEIGHT_ADDR_2:
                    begin
                        if ( (master_waitrequest == 1'b0) && (master_readdatavalid == 1'b1) )
                            next_state = `READ_INPUT_ACTIVATION_ADDR;
                        else
                            next_state = `READ_WEIGHT_ADDR_2;
                    end
                `READ_INPUT_ACTIVATION_ADDR:
                    begin
                        if (cache_valid == 1'b1)
                            next_state = `READ_INPUT_ACTIVATION_ADDR_2;

                        else if ( master_waitrequest == 1'b1 )
                            next_state = `READ_INPUT_ACTIVATION_ADDR;
                        else
                            next_state = `READ_INPUT_ACTIVATION_ADDR_2;
                    end
                `READ_INPUT_ACTIVATION_ADDR_2:
                    begin
                        if (cache_valid == 1'b1)
                            next_state = `A_MULT_B;

                        else if ( (master_waitrequest == 1'b0) && (master_readdatavalid == 1'b1) )
                            next_state = `A_MULT_B;
                        else
                            next_state = `READ_INPUT_ACTIVATION_ADDR_2;
                    end
                `A_MULT_B:
                    begin
                        if (element_count_finished_inner == 1'b1)
                            next_state = `APPLY_Q1616_PLUS_B;
                        else
                            next_state = `READ_WEIGHT_ADDR;
                    end
                `APPLY_Q1616_PLUS_B: next_state = `APPLY_RELU;
                `APPLY_RELU: next_state = `WRITE_OUTPUT_ACTIVATION_ADDR;
                `WRITE_OUTPUT_ACTIVATION_ADDR:
                    begin
                        if (master_waitrequest == 1'b1)
                            next_state = `WRITE_OUTPUT_ACTIVATION_ADDR;
                        else
                            next_state = `CHECK_VECTOR_LENGTH_DONE;
                    end
                `CHECK_VECTOR_LENGTH_DONE:
                    begin
                        if ( master_waitrequest == 1'b1 )
                            next_state = `CHECK_VECTOR_LENGTH_DONE;

                        else if (element_count_finished == 1'b1)
                            next_state = `PRE_CPU_READ_IDLE;
                        else
                            next_state = `READ_BIAS_ADDR;
                    end
                `PRE_CPU_READ_IDLE:
                    begin
                        if ( (slave_address == 4'b0) && (slave_read == 1'b1) )
                            next_state = `OFFSET_IDLE;
                        else
                            next_state = `PRE_CPU_READ_IDLE;
                    end
                default: next_state = 5'bx;
            endcase
        end

always@(*)
    begin
        case (present_state)
            `RESET:
                begin
                    slave_waitrequest = 1'bx;
                    slave_readdata = 32'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    address_count = 1'bx;
                    address_reset = 1'bx;
                    assign_bias = 1'bx;
                    assign_weight = 1'bx;
                    assign_activation = 1'bx;
                    assign_output_activation = 1'bx;
                    assign_vector_length = 1'bx;
                    vector_length_reset = 1'bx;
                    element_count_up = 1'bx;
                    element_count_reset = 1'bx;
                    assign_relu_or_norelu = 1'bx;
                    relu_or_norelu_reset = 1'bx;
                    activation_element = 32'bx;
                    bias_element = 32'bx;
                    weight_element = 32'bx;
                    w_a = 64'bx;
                    Q1616_w_a_plus_b = 32'bx;
                    relu_Q1616_w_a_plus_b = 32'bx;
                    inner_address_reset = 1'bx;
                    inner_address_count = 1'bx;
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    // new addition
                    previous_activation_vector_addr = 32'bx;
                    previous_vector_length = 32'bx;
                    cache_valid = 1'b0;
                    cache_current_element = cache_current_element;
                end
            `OFFSET_IDLE:
                begin
                    case (slave_address)
                        4'd0:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b0;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        4'd1:
                            begin
                                assign_bias = 1'b1;
                                assign_weight = 1'b0;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        4'd2:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b1;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        4'd3:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b0;
                                assign_activation = 1'b1;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        4'd4:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b0;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b1;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        4'd5:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b0;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b1;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        4'd6:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b0;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        4'd7:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b0;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b1;

                                previous_activation_vector_addr = previous_activation_vector_addr;
                                previous_vector_length = previous_vector_length;
                            end
                        default:
                            begin
                                assign_bias = 1'b0;
                                assign_weight = 1'b0;
                                assign_activation = 1'b0;
                                assign_output_activation = 1'b0;
                                assign_vector_length = 1'b0;
                                assign_relu_or_norelu = 1'b0;

                                previous_activation_vector_addr = 32'bx;
                                previous_vector_length = 32'bx;
                            end
                    endcase

                    slave_waitrequest = 1'b0;
                    slave_readdata = 32'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = 32'bx;
                    bias_element = 32'bx;
                    weight_element = 32'bx;
                    w_a = 64'b0;
                    Q1616_w_a_plus_b = 32'bx;
                    relu_Q1616_w_a_plus_b = 32'bx;

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    if (previous_activation_vector_addr == current_activation_vector_addr && previous_vector_length == vector_length)
                        cache_valid = 1'b1;
                    else
                        cache_valid = cache_valid;
                    
                    cache_current_element = cache_current_element;
                end

            `READ_BIAS_ADDR:
                begin
                    if (master_waitrequest == 1'b1)
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_writedata = 32'bx;
                            master_write = 1'bx;
                            bias_element = bias_element;
                        end

                    else 
                        begin
                            master_address = inc_current_bias_vector_addr;
                            master_read = 1'b1;
                            master_write = 1'b0;
                            master_writedata = 32'bx;
                            bias_element = bias_element;
                        end

                    /*
                    else
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;
                            bias_element = master_readdata;
                        end
                    */

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    weight_element = weight_element;
                    w_a = w_a;
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b; 

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end
            
            `READ_BIAS_ADDR_2:
                begin
                    // for controlling steady signal, and to ensure that if wait request goes low and readdata valid isnt high yet, to not start a new request
                    if (master_waitrequest == 1'b1)
                        begin
                            master_address = inc_current_bias_vector_addr;
                            master_read = 1'b1;
                            master_write = 1'b0;
                            master_writedata = 32'bx;
                        end
                    else
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;    
                        end
                    
                    if (master_readdatavalid == 1'b1)
                        bias_element = master_readdata;
                    else 
                        bias_element = bias_element;

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    weight_element = weight_element;
                    w_a = w_a;
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b; 

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end

            `READ_WEIGHT_ADDR:
                begin
                    if (master_waitrequest == 1'b1)
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_writedata = 32'bx;
                            master_write = 1'bx;
                            weight_element = weight_element;
                        end

                    else
                        begin
                            master_address = inc_inner_weight_vector;
                            master_read = 1'b1;
                            master_write = 1'b0;
                            master_writedata = 32'bx;
                            weight_element = weight_element;
                        end
                    /*
                    else
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;
                            weight_element = master_readdata;
                        end
                    */

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    bias_element = bias_element;
                    w_a = w_a;
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b; 

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx; 

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end
            
            `READ_WEIGHT_ADDR_2:
                begin
                    // for controlling steady signal, and to ensure that if wait request goes low and readdata valid isnt high yet, to not start a new request
                    if (master_waitrequest == 1'b1)
                        begin
                            master_address = inc_inner_weight_vector;
                            master_read = 1'b1;
                            master_write = 1'b0;
                            master_writedata = 32'bx;
                        end
                    else
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;    
                        end
                    
                    if (master_readdatavalid == 1'b1)
                        weight_element = master_readdata;
                    else
                        weight_element = weight_element;
                    
                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    bias_element = bias_element;
                    w_a = w_a;
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b; 

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end

            `READ_INPUT_ACTIVATION_ADDR:
                begin
                    if (cache_valid == 1'b1)
                        begin
                            cache_address = element_current_count_inner[9:0];
                            cache_wren = 1'b0;
                            cache_writedata = 32'bx;

                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_writedata = 32'bx;
                            master_write = 1'bx;
                            activation_element = activation_element;
                        end
                    else if (master_waitrequest == 1'b1)
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_writedata = 32'bx;
                            master_write = 1'bx;
                            activation_element = activation_element;

                            cache_address = 10'bx;
                            cache_wren = 1'bx;
                            cache_writedata = 32'bx;
                            activation_element = activation_element;
                        end

                    else
                        begin
                            master_address = inc_inner_activation_vector;
                            master_read = 1'b1;
                            master_write = 1'b0;
                            master_writedata = 32'bx;
                            activation_element = activation_element;

                            cache_address = 10'bx;
                            cache_wren = 1'bx;
                            cache_writedata = 32'bx;
                            activation_element = activation_element;
                        end
                    /*
                    else
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;
                            activation_element = master_readdata;
                        end
                    */

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    w_a = w_a;
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b;

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end

            `READ_INPUT_ACTIVATION_ADDR_2:
                begin
                    // for controlling steady signal, and to ensure that if wait request goes low and readdata valid isnt high yet, to not start a new request
                    if (cache_valid == 1'b1)
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;
                        end
                    
                    else if (master_waitrequest == 1'b1)
                        begin
                            master_address = inc_inner_activation_vector;
                            master_read = 1'b1;
                            master_write = 1'b0;
                            master_writedata = 32'bx;
                        end
                    else
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;    
                        end
                    
                    if (cache_valid == 1'b1)
                        begin
                            activation_element = cache_readdata;
                            cache_current_element = cache_readdata;
                        end
                    if (master_readdatavalid == 1'b1)
                        begin
                            activation_element = master_readdata;
                            cache_current_element = cache_current_element;
                        end
                    else
                        begin
                            activation_element = activation_element;
                            cache_current_element = cache_current_element;
                        end

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    w_a = w_a;
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b;

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;
                    cache_valid = cache_valid;
                end

            `A_MULT_B:
                begin
                    if (cache_valid == 1'b1)
                        activation_element = cache_current_element;

                    else if (master_readdatavalid == 1'b1)
                        activation_element = master_readdata;
                    else
                        activation_element = activation_element;

                    w_a = ($signed(weight_element) * $signed(activation_element)) + w_a;

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    // activation_element = activation_element;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b;

                    if (element_count_finished_inner == 1'b1)
                        begin
                            inner_address_reset = 1'b1;
                            inner_address_count = 1'b0;
                            element_count_up_inner = 1'b0;
                            element_count_reset_inner = 1'b1;
                        end
                    else
                        begin
                            inner_address_count = 1'b1;
                            inner_address_reset = 1'b0;
                            element_count_up_inner = 1'b1;
                            element_count_reset_inner = 1'b0;
                        end
                    
                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    // writing to the ram
                    cache_address = element_current_count_inner[9:0];
                    cache_wren = 1'b1;
                    cache_writedata = activation_element;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end

            `APPLY_Q1616_PLUS_B:
                begin
                    // NEED TO CHECK THIS OPERATION OVER
                    Q1616_w_a_plus_b = $signed( (w_a + `ROUNDING_CORRECTION) >>> 16) + $signed(bias_element);

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    w_a = w_a;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;
                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end

            `APPLY_RELU:
                begin
                    
                    if (relu_or_norelu != 32'd1)
                        relu_Q1616_w_a_plus_b = Q1616_w_a_plus_b;

                    else if (Q1616_w_a_plus_b[31] == 1'b1)
                        relu_Q1616_w_a_plus_b = 32'b0;

                    else
                        relu_Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    
                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    w_a = 64'b0; // manually resetting it
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end

            `WRITE_OUTPUT_ACTIVATION_ADDR:
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
                            master_address = inc_current_output_activation_vector_addr;
                            master_write = 1'b1;
                            master_read = 1'b0;
                            master_writedata = relu_Q1616_w_a_plus_b;
                        end

                    slave_waitrequest = 1'b1;
                    slave_readdata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b0;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    w_a = 64'b0; // manually resetting
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                end

            `CHECK_VECTOR_LENGTH_DONE:
                begin
                    // for controlling steady signal, and to ensure that if wait request goes low and readdata valid isnt high yet, to not start a new request
                    if (master_waitrequest == 1'b1)
                        begin
                            master_address = inc_current_output_activation_vector_addr;
                            master_write = 1'b1;
                            master_read = 1'b0;
                            master_writedata = relu_Q1616_w_a_plus_b;
                        end
                    else
                        begin
                            master_address = 32'bx;
                            master_read = 1'bx;
                            master_write = 1'bx;
                            master_writedata = 32'bx;    
                        end
    

                    if (element_count_finished == 1'b0 && master_waitrequest == 1'b0)
                        begin
                            address_count = 1'b1;
                            address_reset = 1'b0;
                            element_count_up = 1'b1;
                            element_count_reset = 1'b0;
                        end

                    else if (element_count_finished == 1'b1 && master_waitrequest == 1'b0)
                        begin
                            address_count = 1'b0;
                            address_reset = 1'b1;
                            element_count_up = 1'b0;
                            element_count_reset = 1'b1;
                        end

                    else
                        begin
                            address_count = address_count;
                            address_reset = address_reset;
                            element_count_up = element_count_up;
                            element_count_reset = element_count_reset;
                        end

                    slave_waitrequest =  1'b1;
                    slave_readdata = 32'bx;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b0;
                    activation_element = activation_element;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    w_a = 32'b0; // manually resetting
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;
                    inner_address_reset = 1'bx;
                    inner_address_count = 1'bx;

                    // new addition
                    previous_activation_vector_addr = previous_activation_vector_addr;
                    previous_vector_length = previous_vector_length;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;
                end

            `PRE_CPU_READ_IDLE:
                begin
                    slave_waitrequest = 1'b0;
                    slave_readdata = 32'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    address_count = 1'b0;
                    address_reset = 1'b1;
                    assign_bias = 1'b0;
                    assign_weight = 1'b0;
                    assign_activation = 1'b0;
                    assign_output_activation = 1'b0;
                    assign_vector_length = 1'b0;
                    vector_length_reset = 1'b0;
                    element_count_up = 1'b0;
                    element_count_reset = 1'b1;
                    assign_relu_or_norelu = 1'b0;
                    relu_or_norelu_reset = 1'b1;
                    activation_element = activation_element;
                    bias_element = bias_element;
                    weight_element = weight_element;
                    w_a = 64'b0; // manually resetting it
                    Q1616_w_a_plus_b = Q1616_w_a_plus_b;
                    relu_Q1616_w_a_plus_b = relu_Q1616_w_a_plus_b;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;
                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    // new addition
                    previous_activation_vector_addr = current_activation_vector_addr;
                    previous_vector_length = vector_length;
                    cache_valid = cache_valid;
                    cache_current_element = cache_current_element;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                end

            default:
                begin
                    slave_waitrequest = 1'bx;
                    slave_readdata = 32'bx;
                    master_address = 32'bx;
                    master_read = 1'bx;
                    master_write = 1'bx;
                    master_writedata = 32'bx;
                    address_count = 1'bx;
                    address_reset = 1'bx;
                    assign_bias = 1'bx;
                    assign_weight = 1'bx;
                    assign_activation = 1'bx;
                    assign_output_activation = 1'bx;
                    assign_vector_length = 1'bx;
                    vector_length_reset = 1'b1;
                    element_count_up = 1'bx;
                    element_count_reset = 1'b1;
                    assign_relu_or_norelu = 1'bx;
                    relu_or_norelu_reset = 1'bx;
                    activation_element = 32'bx;
                    bias_element = 32'bx;
                    weight_element = 32'bx;
                    w_a = 64'bx;
                    Q1616_w_a_plus_b = 32'bx;
                    relu_Q1616_w_a_plus_b = 32'bx;

                    
                    element_count_reset_inner = 1'bx;
                    element_count_up_inner = 1'bx;
                    inner_address_count = 1'bx;
                    inner_address_reset = 1'bx;

                    previous_activation_vector_addr = 32'bx;
                    previous_vector_length = 32'bx;
                    cache_valid = 1'bx;
                    cache_current_element = 32'bx;

                    cache_address = 10'bx;
                    cache_wren = 1'bx;
                    cache_writedata = 32'bx;
                end
        endcase   
    end
endmodule: dnn

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