module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 8    
) (
    input  wire                    
    input  wire                   

    input  wire                   
    input  wire [DATA_WIDTH-1:0]  
    output wire                    

    input  wire                   
    output wire [DATA_WIDTH-1:0]  
    output wire                    
);

   
    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

   
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    
    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    
    reg [DATA_WIDTH-1:0] rd_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr      <= 0;
            rd_data_reg <= 0;
        end else if (rd_en && !empty) begin
            rd_data_reg <= mem[rd_ptr[PTR_WIDTH-1:0]];
            rd_ptr      <= rd_ptr + 1'b1;
        end
    end

    assign rd_data = rd_data_reg;

  
    assign empty = (wr_ptr == rd_ptr);

    
    assign full = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                  (wr_ptr[PTR_WIDTH]     != rd_ptr[PTR_WIDTH]);

endmodule
