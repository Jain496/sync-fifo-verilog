// =============================================================
// tb_fifo.v -- Self-checking testbench for sync_fifo
// Part A: directed tests (fill to full, drain to empty, simultaneous
//         read+write, overflow/underflow protection)
// Part B: randomized test with a software scoreboard queue
// =============================================================
`timescale 1ns/1ps

module tb_fifo;

    localparam DATA_WIDTH = 8;
    localparam FIFO_DEPTH = 8;
    localparam CLK_PERIOD_NS = 10;

    reg                    clk;
    reg                    rst_n;
    reg                    wr_en;
    reg  [DATA_WIDTH-1:0]  wr_data;
    wire                   full;
    reg                    rd_en;
    wire [DATA_WIDTH-1:0]  rd_data;
    wire                   empty;

    integer errors;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) DUT (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data), .full(full),
        .rd_en(rd_en), .rd_data(rd_data), .empty(empty)
    );

    // Free-running clock
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // ---------------------------------------------------------
    // Software "model" queue -- a plain Verilog array acting as
    // our reference FIFO, so we know the exact expected order of
    // data coming back out, independent of the DUT.
    // ---------------------------------------------------------
    reg [DATA_WIDTH-1:0] model_q [0:255];
    integer model_head, model_tail, model_count;

    task model_push(input [DATA_WIDTH-1:0] d);
        begin
            model_q[model_tail] = d;
            model_tail = (model_tail + 1) % 256;
            model_count = model_count + 1;
        end
    endtask

    task model_pop_and_check(input [DATA_WIDTH-1:0] actual);
        reg [DATA_WIDTH-1:0] expected;
        begin
            expected = model_q[model_head];
            model_head = (model_head + 1) % 256;
            model_count = model_count - 1;
            if (actual === expected) begin
                $display("PASS: expected 0x%0h  got 0x%0h", expected, actual);
            end else begin
                $display("FAIL: expected 0x%0h  got 0x%0h", expected, actual);
                errors = errors + 1;
            end
        end
    endtask

    // Simple helper tasks to pulse write/read for exactly one cycle
    task do_write(input [DATA_WIDTH-1:0] d);
        begin
            @(negedge clk);
            wr_data = d;
            wr_en   = 1'b1;
            @(negedge clk);
            wr_en   = 1'b0;
        end
    endtask

    task do_read;
        begin
            @(negedge clk);
            rd_en = 1'b1;
            @(negedge clk);
            rd_en = 1'b0;
        end
    endtask

    integer i;

    initial begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, tb_fifo);

        clk = 0; rst_n = 0;
        wr_en = 0; wr_data = 0; rd_en = 0;
        errors = 0;
        model_head = 0; model_tail = 0; model_count = 0;

        #(CLK_PERIOD_NS*3);
        rst_n = 1;
        #(CLK_PERIOD_NS*2);

        // ===================================================
        // PART A -- Directed tests
        // ===================================================

        // A1: FIFO should start empty
        if (empty !== 1'b1) begin
            $display("FAIL: FIFO should be empty after reset");
            errors = errors + 1;
        end else begin
            $display("PASS: FIFO is empty after reset");
        end

        // A2: Write until full (write exactly FIFO_DEPTH items)
        $display("\n-- A2: Filling FIFO to full --");
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            do_write(i);
            model_push(i);
        end
        if (full !== 1'b1) begin
            $display("FAIL: FIFO should be FULL after writing %0d items", FIFO_DEPTH);
            errors = errors + 1;
        end else begin
            $display("PASS: FIFO correctly reports FULL after %0d writes", FIFO_DEPTH);
        end

        // A3: Attempt to write while full -- must be ignored (overflow protection)
        do_write(8'hEE);   // this value should NOT enter the FIFO
        if (full !== 1'b1) begin
            $display("FAIL: an extra write while full corrupted the FIFO state");
            errors = errors + 1;
        end else begin
            $display("PASS: write while FULL was correctly ignored");
        end

        // A4: Drain to empty, checking every value comes out in order
        $display("\n-- A4: Draining FIFO to empty --");
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            do_read;
            model_pop_and_check(rd_data);
        end
        if (empty !== 1'b1) begin
            $display("FAIL: FIFO should be EMPTY after draining all items");
            errors = errors + 1;
        end else begin
            $display("PASS: FIFO correctly reports EMPTY after full drain");
        end

        // A5: Attempt to read while empty -- must be ignored (underflow protection)
        do_read;
        if (empty !== 1'b1) begin
            $display("FAIL: an extra read while empty corrupted the FIFO state");
            errors = errors + 1;
        end else begin
            $display("PASS: read while EMPTY was correctly ignored");
        end

        // A6: Simultaneous write + read on a partially-filled FIFO
        $display("\n-- A6: Simultaneous write + read --");
        do_write(8'hA5);
        model_push(8'hA5);
        do_write(8'h5A);
        model_push(8'h5A);

        @(negedge clk);
        wr_en = 1'b1; wr_data = 8'h3C;
        rd_en = 1'b1;
        @(negedge clk);
        wr_en = 1'b0; rd_en = 1'b0;
        model_push(8'h3C);
        model_pop_and_check(rd_data);

        // drain the remaining 2 items
        do_read; model_pop_and_check(rd_data);
        do_read; model_pop_and_check(rd_data);

        // ===================================================
        // PART B -- Randomized test
        // ===================================================
        $display("\n-- B: Randomized write/read sequence (50 operations) --");
        for (i = 0; i < 50; i = i + 1) begin
            if ($random % 2 == 0 && !full) begin
                do_write($random & 8'hFF);
                model_push(wr_data);
            end else if (!empty) begin
                do_read;
                model_pop_and_check(rd_data);
            end
        end
        // drain whatever is left so the model queue empties out too
        while (model_count > 0) begin
            do_read;
            model_pop_and_check(rd_data);
        end

        // ===================================================
        // Summary
        // ===================================================
        if (errors == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** TEST FAILED: %0d errors ***", errors);

        $finish;
    end

endmodule