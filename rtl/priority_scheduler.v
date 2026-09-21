`timescale 1ns/1ps
// FlowGuard-RTL
// Adaptive priority + bounded-wait scheduler.
// Direction encoding: 0 = North-South, 1 = East-West.
// Plain Verilog (IEEE 1364-2005) version.

module priority_scheduler #(
    parameter MIN_GREEN  = 4,
    parameter MAX_GREEN  = 12,
    parameter MAX_WAIT   = 10,
    parameter WAIT_SHIFT = 2
) (
    input  wire [2:0] traffic_ns,
    input  wire [2:0] traffic_ew,
    input  wire [7:0] wait_ns,
    input  wire [7:0] wait_ew,
    input  wire       last_dir,

    output reg        selected_dir,
    output reg  [7:0] selected_green_time,
    output reg  [7:0] ns_green_time,
    output reg  [7:0] ew_green_time,
    output reg  [7:0] ns_score,
    output reg  [7:0] ew_score
);

    reg [7:0] ns_wait_bonus;
    reg [7:0] ew_wait_bonus;
    integer   ns_time_calc;
    integer   ew_time_calc;

    // Traffic demand is encoded from 0 (empty) to 7 (very high).
    // Higher demand receives more green time, subject to hard limits.
    always @(*) begin
        ns_time_calc = MIN_GREEN + (traffic_ns * 2);
        ew_time_calc = MIN_GREEN + (traffic_ew * 2);

        if (ns_time_calc > MAX_GREEN)
            ns_time_calc = MAX_GREEN;
        if (ew_time_calc > MAX_GREEN)
            ew_time_calc = MAX_GREEN;

        ns_green_time = ns_time_calc;
        ew_green_time = ew_time_calc;

        // Aging bonus prevents one busy direction from dominating forever.
        ns_wait_bonus = (WAIT_SHIFT >= 8) ? 8'd0 : (wait_ns >> WAIT_SHIFT);
        ew_wait_bonus = (WAIT_SHIFT >= 8) ? 8'd0 : (wait_ew >> WAIT_SHIFT);

        ns_score = {5'd0, traffic_ns} + ns_wait_bonus;
        ew_score = {5'd0, traffic_ew} + ew_wait_bonus;

        // Do not give service to an empty road when the other road has demand.
        if ((traffic_ns == 3'd0) && (traffic_ew != 3'd0)) begin
            selected_dir = 1'b1;
        end else if ((traffic_ew == 3'd0) && (traffic_ns != 3'd0)) begin
            selected_dir = 1'b0;
        // Hard fairness limit: once a non-empty direction reaches MAX_WAIT,
        // it is selected at the next safe scheduling point.
        end else if ((wait_ns >= MAX_WAIT) && (traffic_ns != 3'd0) &&
                     ((traffic_ew == 3'd0) || (wait_ew < MAX_WAIT))) begin
            selected_dir = 1'b0;
        end else if ((wait_ew >= MAX_WAIT) && (traffic_ew != 3'd0) &&
                     ((traffic_ns == 3'd0) || (wait_ns < MAX_WAIT))) begin
            selected_dir = 1'b1;
        // Otherwise use demand + aging score.
        end else if (ns_score > ew_score) begin
            selected_dir = 1'b0;
        end else if (ew_score > ns_score) begin
            selected_dir = 1'b1;
        end else begin
            // Deterministic alternating tie-breaker.
            selected_dir = ~last_dir;
        end

        selected_green_time = selected_dir ? ew_green_time : ns_green_time;
    end

endmodule
