`timescale 1ns/1ps
// FlowGuard-RTL
// Five-state Moore FSM with programmable phase timing.
// State encoding: NS_GREEN, NS_YELLOW, ALL_RED, EW_GREEN, EW_YELLOW.
// Plain Verilog (IEEE 1364-2005) version.

module traffic_fsm #(
    parameter YELLOW_TIME   = 2,
    parameter ALL_RED_TIME  = 1
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       selected_dir,
    input  wire [7:0] selected_green_time,

    output reg  [2:0] state,
    output reg        ns_red,
    output reg        ns_yellow,
    output reg        ns_green,
    output reg        ew_red,
    output reg        ew_yellow,
    output reg        ew_green
);

    localparam [2:0] NS_GREEN  = 3'd0;
    localparam [2:0] NS_YELLOW = 3'd1;
    localparam [2:0] ALL_RED   = 3'd2;
    localparam [2:0] EW_GREEN  = 3'd3;
    localparam [2:0] EW_YELLOW = 3'd4;

    reg [7:0] phase_count;
    reg [7:0] green_limit;
    reg [2:0] next_state;
    integer   active_limit;

    always @(*) begin
        active_limit = 1;

        case (state)
            NS_GREEN,
            EW_GREEN: active_limit = (green_limit == 0) ? 1 : green_limit;
            NS_YELLOW,
            EW_YELLOW: active_limit = (YELLOW_TIME == 0) ? 1 : YELLOW_TIME;
            ALL_RED: active_limit = (ALL_RED_TIME == 0) ? 1 : ALL_RED_TIME;
            default: active_limit = 1;
        endcase

        next_state = state;

        // phase_count is the number of completed clock intervals in the
        // current state. A transition occurs after active_limit intervals.
        if ((state == NS_GREEN) || (state == EW_GREEN) ||
            (state == NS_YELLOW) || (state == EW_YELLOW) ||
            (state == ALL_RED)) begin
            if ((phase_count + 1) >= active_limit) begin
                case (state)
                    NS_GREEN:  next_state = NS_YELLOW;
                    NS_YELLOW: next_state = ALL_RED;
                    ALL_RED:   next_state = selected_dir ? EW_GREEN : NS_GREEN;
                    EW_GREEN:  next_state = EW_YELLOW;
                    EW_YELLOW: next_state = ALL_RED;
                    default:   next_state = ALL_RED;
                endcase
            end
        end else begin
            // Safe recovery path from any illegal state.
            next_state = ALL_RED;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset must land in a safe state, not a green phase. ALL_RED
            // is the fail-safe state; the normal ALL_RED -> {NS,EW}_GREEN
            // transition latches the correct green_limit from
            // selected_green_time once the scheduler has settled.
            state       <= ALL_RED;
            phase_count <= 8'd0;
            green_limit <= 8'd1;
        end else begin
            state <= next_state;

            if (state != next_state) begin
                phase_count <= 8'd0;

                // Latch the selected green duration on entry to a green state.
                if (next_state == NS_GREEN || next_state == EW_GREEN) begin
                    green_limit <= (selected_green_time == 0) ? 8'd1 : selected_green_time;
                end
            end else begin
                if (phase_count != 8'hFF)
                    phase_count <= phase_count + 8'd1;
            end
        end
    end

    // Moore outputs. These are deliberately simple and deterministic.
    always @(*) begin
        ns_red    = 1'b0;
        ns_yellow = 1'b0;
        ns_green  = 1'b0;
        ew_red    = 1'b0;
        ew_yellow = 1'b0;
        ew_green  = 1'b0;

        case (state)
            NS_GREEN: begin
                ns_green = 1'b1;
                ew_red   = 1'b1;
            end
            NS_YELLOW: begin
                ns_yellow = 1'b1;
                ew_red    = 1'b1;
            end
            ALL_RED: begin
                ns_red = 1'b1;
                ew_red = 1'b1;
            end
            EW_GREEN: begin
                ns_red   = 1'b1;
                ew_green = 1'b1;
            end
            EW_YELLOW: begin
                ns_red    = 1'b1;
                ew_yellow = 1'b1;
            end
            default: begin
                ns_red = 1'b1;
                ew_red = 1'b1;
            end
        endcase
    end

endmodule
