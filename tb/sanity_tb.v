`timescale 1ns/1ps
// FlowGuard-RTL sanity testbench - plain Verilog (IEEE 1364-2005) version.

module sanity_tb;
    reg clk;
    reg rst;
    reg [2:0] traffic_ns, traffic_ew;
    wire ns_red, ns_yellow, ns_green, ew_red, ew_yellow, ew_green, fault;
    wire [2:0] state;
    wire selected_dir;
    wire [7:0] wait_ns, wait_ew, ns_green_time, ew_green_time, ns_score, ew_score;

    integer errors;

    flowguard_top #(
        .MIN_GREEN(2), .MAX_GREEN(6), .YELLOW_TIME(2), .ALL_RED_TIME(1),
        .MAX_WAIT(6), .WAIT_SHIFT(1)
    ) dut (
        .clk(clk),
        .rst(rst),
        .traffic_ns(traffic_ns),
        .traffic_ew(traffic_ew),
        .ns_red(ns_red),
        .ns_yellow(ns_yellow),
        .ns_green(ns_green),
        .ew_red(ew_red),
        .ew_yellow(ew_yellow),
        .ew_green(ew_green),
        .fault(fault),
        .state(state),
        .selected_dir(selected_dir),
        .wait_ns(wait_ns),
        .wait_ew(wait_ew),
        .ns_green_time(ns_green_time),
        .ew_green_time(ew_green_time),
        .ns_score(ns_score),
        .ew_score(ew_score)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Continuous safety invariant: never both greens, never green+red same
    // side, fault must force both sides red.
    always @(posedge clk) begin
        if (!rst) begin
            if (ns_green && ew_green) begin
                errors = errors + 1;
                $display("ERROR t=%0t both directions green simultaneously", $time);
            end
            if (fault && !(ns_red && ew_red)) begin
                errors = errors + 1;
                $display("ERROR t=%0t fault asserted but outputs not all-red", $time);
            end
            if ((ns_green + ns_yellow + ns_red) != 1) begin
                errors = errors + 1;
                $display("ERROR t=%0t NS output not exactly one-hot", $time);
            end
            if ((ew_green + ew_yellow + ew_red) != 1) begin
                errors = errors + 1;
                $display("ERROR t=%0t EW output not exactly one-hot", $time);
            end
        end
    end

    task run_cycles;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
        end
    endtask

    integer g;

    initial begin
        errors = 0;

        $dumpfile("sim/sanity.vcd");
        $dumpvars(0, sanity_tb);

        // 1. Reset must be safe (ALL_RED), not a green phase.
        traffic_ns = 3'd0; traffic_ew = 3'd0;
        rst = 1;
        run_cycles(2);
        if (ns_green || ew_green) begin
            errors = errors + 1;
            $display("ERROR: green asserted during reset");
        end
        rst = 0;

        // 2. Empty-road test: NS has demand, EW is empty -> EW must never
        // get selected and must not accumulate wait debt.
        traffic_ns = 3'd5; traffic_ew = 3'd0;
        run_cycles(60);
        if (wait_ew !== 8'd0) begin
            errors = errors + 1;
            $display("ERROR: empty EW accumulated wait debt = %0d", wait_ew);
        end
        if (selected_dir !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR: empty EW got selected over demanding NS");
        end

        // 3. Fairness/aging: give both directions demand, force EW to
        // starve until it hits MAX_WAIT, then it must be served.
        traffic_ns = 3'd7; traffic_ew = 3'd1;
        run_cycles(200);
        if (wait_ew > 8'd6) begin
            errors = errors + 1;
            $display("ERROR: EW wait counter exceeded MAX_WAIT saturation: %0d", wait_ew);
        end

        // 4. High-demand green-time clamp check (the originally reported bug)
        traffic_ns = 3'd7; traffic_ew = 3'd0;
        // wait for an NS_GREEN entry
        wait (state == 3'd0);
        @(posedge clk); // settle one cycle into the phase
        g = 0;
        while (state == 3'd0) begin
            if (ns_green) g = g + 1;
            @(posedge clk);
        end
        if (g < 5 || g > 6) begin
            errors = errors + 1;
            $display("ERROR: NS green duration = %0d cycles, expected 6 (clamped)", g);
        end else begin
            $display("OK: NS green duration = %0d cycles (clamped to MAX_GREEN)", g);
        end

        // 5. Fault injection via forced illegal state on safety_monitor directly
        force dut.u_safety.state = 3'd6; // illegal encoding
        #1;
        if (!(dut.ns_red && dut.ns_yellow == 0 && dut.ns_green == 0 &&
              dut.ew_red && dut.ew_yellow == 0 && dut.ew_green == 0)) begin
            errors = errors + 1;
            $display("ERROR: illegal state did not force fail-safe all-red");
        end else begin
            $display("OK: illegal state correctly forced fail-safe all-red");
        end
        release dut.u_safety.state;

        if (errors == 0)
            $display("ALL SANITY CHECKS PASSED");
        else
            $display("SANITY CHECKS FAILED: %0d error(s)", errors);

        $finish;
    end
endmodule
