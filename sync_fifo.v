// =============================================================
// sync_fifo.v -- Parameterized Synchronous FIFO
// Single clock domain. FIFO_DEPTH must be a power of 2.
// =============================================================
module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 8     // must be a power of 2 (8, 16, 32, ...)
) (
    input  wire                    clk,
    input  wire                    rst_n,     // active-low synchronous reset

    input  wire                    wr_en,     // write enable
    input  wire [DATA_WIDTH-1:0]   wr_data,   // data to write
    output wire                    full,      // FIFO is full, don't write

    input  wire                    rd_en,     // read enable
    output wire [DATA_WIDTH-1:0]   rd_data,   // data read out
    output wire                    empty      // FIFO is empty, don't read
);

    // Number of bits needed to address FIFO_DEPTH locations
    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

    // The actual storage: FIFO_DEPTH words, each DATA_WIDTH bits wide
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    // Pointers are ONE BIT WIDER than needed to address memory.
    // That extra top bit is the trick that lets us tell full apart
    // from empty using simple pointer comparison (see full/empty logic).
    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    // ---------------- Write logic ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // ---------------- Read logic ----------------
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

    // ---------------- Full / Empty flags ----------------
    // EMPTY: write pointer and read pointer are identical (including
    // the extra top bit) -- nothing has been written that hasn't
    // already been read.
    assign empty = (wr_ptr == rd_ptr);

    // FULL: the lower address bits match (same physical slot) BUT the
    // extra top bit differs -- meaning the write pointer has wrapped
    // around the memory exactly one more time than the read pointer.
    assign full = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                  (wr_ptr[PTR_WIDTH]     != rd_ptr[PTR_WIDTH]);

endmodule