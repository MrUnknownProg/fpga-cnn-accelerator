`timescale 1ns/1ps

module tb_pool;

parameter IMG_W  = 6;
parameter DATA_W = 20;

reg clk;
reg rst;
reg en;
reg signed [DATA_W-1:0] pixel_in;

wire signed [DATA_W-1:0] row0_out;
wire signed [DATA_W-1:0] row1_out;

wire signed [DATA_W-1:0] pool_out;
wire pool_valid;

integer r,c;
integer pool_cnt;

///////////////////////////////////////////////////////////
// CLOCK
///////////////////////////////////////////////////////////

initial clk = 0;
always #5 clk = ~clk;

///////////////////////////////////////////////////////////
// LINE BUFFER
///////////////////////////////////////////////////////////

linebuffer_2x2 #(
    .IMG_W(IMG_W)
)
LB
(
    .clk(clk),
    .rst(rst),
    .en(en),
    .pixel_in(pixel_in),

    .row0(row0_out),
    .row1(row1_out)
);

///////////////////////////////////////////////////////////
// MAXPOOL
///////////////////////////////////////////////////////////

maxpool #(
    .IMG_W(IMG_W),
    .DATA_W(DATA_W)
)
DUT
(
    .clk(clk),
    .rst(rst),
    .en(en),

    .row0_in(row0_out),
    .row1_in(row1_out),

    .data_out(pool_out),
    .valid_out(pool_valid)
);

///////////////////////////////////////////////////////////
// STIMULUS
///////////////////////////////////////////////////////////

initial begin

    rst = 1;
    en  = 0;
    pixel_in = 0;

    #30;

    rst = 0;
    en  = 1;

    ///////////////////////////////////////////////////////
    // Feed 6x6 image
    ///////////////////////////////////////////////////////

    for(r=0;r<IMG_W;r=r+1)
    begin
        for(c=0;c<IMG_W;c=c+1)
        begin
            
            
            pixel_in <= r*IMG_W + c;
            @(posedge clk);
            

        end
    end

    @(posedge clk);
    en <= 0;

    #100;
    
    $finish;

end

///////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////

always @(posedge clk)
begin
    if(pool_valid)
    begin
        $display(
        "TL=%0d TR=%0d BL=%0d BR=%0d",
        DUT.row1_prev,
        DUT.row1_in,
        DUT.row0_prev,
        DUT.row0_in);
    end
end

//always @(posedge clk)
//begin
    
//    if(pool_valid)
//        $display("Data_out=%0d", DUT.data_out);
//end

///////////////////////////////////////////////////////////
// POOL OUTPUTS
///////////////////////////////////////////////////////////

initial pool_cnt = 0;

always @(posedge clk)
begin

    if(pool_valid)
    begin        
        $display("FUNC=%0d",
    DUT.max_of_4(
        DUT.row0_prev,
        DUT.row0_in,
        DUT.row1_prev,
        DUT.row1_in
    ));
    $display("RAW row0_prev=%0d row0_in=%0d row1_prev=%0d row1_in=%0d",
         DUT.row0_prev,DUT.row0_in,DUT.row1_prev,DUT.row1_in);

    end

end


always @(negedge clk)
begin
    
    if(pool_valid)
    begin
        $display("POOL[%0d] = %0d",
                 pool_cnt,
                 DUT.data_out);
        
        pool_cnt = pool_cnt + 1;
    end
end
///////////////////////////////////////////////////////////
// FINISH CHECK
///////////////////////////////////////////////////////////

always @(negedge en)
begin

    #20;

    $display("================================");
    $display("POOL COUNT = %0d", pool_cnt);
    $display("EXPECTED   = 9");
    $display("================================");

end

endmodule