`timescale 1ns/1ps
// FlowGuard-RTL
// Top-level adaptive, fair and fail-safe traffic controller.
// Plain Verilog (IEEE 1364-2005) version.

module flowguard_top #(
    parameter MIN_GREEN    = 4,
    parameter MAX_GREEN    = 12,
    parameter YELLOW_TIME  = 2,
    parameter ALL_RED_TIME = 1,
    parameter MAX_WAIT     = 10,
    parameter WAIT_SHIFT   = 2
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] traffic_ns,
    input  wire [2:0] traffic_ew,

    output wire        ns_red,
    output wire        ns_yellow,
    output wire        ns_green,
    output wire        ew_red,
    output wire        ew_yellow,
    output wire        ew_green,

    output wire        fault,
    output wire [2:0]  state,
    output wire        selected_dir,
    output reg  [7:0]  wait_ns,
    output reg  [7:0]  wait_ew,
    output wire [7:0]  ns_green_time,
    output wire [7:0]  ew_green_time,
    output wire [7:0]  ns_score,
    output wire [7:0]  ew_score
);

    wire [7:0] selected_green_time;
    reg        last_dir;

    wire ns_red_raw, ns_yellow_raw, ns_green_raw;
    wire ew_red_raw, ew_yellow_raw, ew_green_raw;
    wire safety_fault;

    priority_scheduler #(
        .MIN_GREEN(MIN_GREEN),
        .MAX_GREEN(MAX_GREEN),
        .MAX_WAIT(MAX_WAIT),
        .WAIT_SHIFT(WAIT_SHIFT)
    ) u_scheduler (
        .traffic_ns(traffic_ns),
        .traffic_ew(traffic_ew),
        .wait_ns(wait_ns),
        .wait_ew(wait_ew),
        .last_dir(last_dir),
        .selected_dir(selected_dir),
        .selected_green_time(selected_green_time),
        .ns_green_time(ns_green_time),
        .ew_green_time(ew_green_time),
        .ns_score(ns_score),
        .ew_score(ew_score)
    );

    traffic_fsm #(
        .YELLOW_TIME(YELLOW_TIME),
        .ALL_RED_TIME(ALL_RED_TIME)
    ) u_fsm (
        .clk(clk),
        .rst(rst),
        .selected_dir(selected_dir),
        .selected_green_time(selected_green_time),
        .state(state),
        .ns_red(ns_red_raw),
        .ns_yellow(ns_yellow_raw),
        .ns_green(ns_green_raw),
        .ew_red(ew_red_raw),
        .ew_yellow(ew_yellow_raw),
        .ew_green(ew_green_raw)
    );

    // Wait counters measure how long an active-demand direction has gone
    // without receiving green. Empty directions do not accumulate waiting time.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wait_ns  <= 8'd0;
            wait_ew  <= 8'd0;
            last_dir <= 1'b0;
        end else begin
            if (ns_green_raw) begin
                wait_ns <= 8'd0;
                if (traffic_ew == 3'd0)
                    wait_ew <= 8'd0;
                else if (wait_ew < MAX_WAIT)
                    wait_ew <= wait_ew + 8'd1;
            end else if (ew_green_raw) begin
                wait_ew <= 8'd0;
                if (traffic_ns == 3'd0)
                    wait_ns <= 8'd0;
                else if (wait_ns < MAX_WAIT)
                    wait_ns <= wait_ns + 8'd1;
            end else begin
                if (traffic_ns == 3'd0)
                    wait_ns <= 8'd0;
                else if (wait_ns < MAX_WAIT)
                    wait_ns <= wait_ns + 8'd1;

                if (traffic_ew == 3'd0)
                    wait_ew <= 8'd0;
                else if (wait_ew < MAX_WAIT)
                    wait_ew <= wait_ew + 8'd1;
            end

            if (ns_green_raw)
                last_dir <= 1'b0;
            else if (ew_green_raw)
                last_dir <= 1'b1;
        end
    end

    safety_monitor u_safety (
        .state(state),
        .ns_red_raw(ns_red_raw),
        .ns_yellow_raw(ns_yellow_raw),
        .ns_green_raw(ns_green_raw),
        .ew_red_raw(ew_red_raw),
        .ew_yellow_raw(ew_yellow_raw),
        .ew_green_raw(ew_green_raw),
        .fault(safety_fault),
        .ns_red(ns_red),
        .ns_yellow(ns_yellow),
        .ns_green(ns_green),
        .ew_red(ew_red),
        .ew_yellow(ew_yellow),
        .ew_green(ew_green)
    );

    assign fault = safety_fault;

endmodule
