`timescale 1ns/1ps
// FlowGuard-RTL
// Independent combinational safety checker and fail-safe output override.
// Plain Verilog (IEEE 1364-2005) version.

module safety_monitor (
    input  wire [2:0] state,
    input  wire       ns_red_raw,
    input  wire       ns_yellow_raw,
    input  wire       ns_green_raw,
    input  wire       ew_red_raw,
    input  wire       ew_yellow_raw,
    input  wire       ew_green_raw,

    output reg         fault,
    output reg         ns_red,
    output reg         ns_yellow,
    output reg         ns_green,
    output reg         ew_red,
    output reg         ew_yellow,
    output reg         ew_green
);

    localparam [2:0] NS_GREEN  = 3'd0;
    localparam [2:0] NS_YELLOW = 3'd1;
    localparam [2:0] ALL_RED   = 3'd2;
    localparam [2:0] EW_GREEN  = 3'd3;
    localparam [2:0] EW_YELLOW = 3'd4;

    always @(*) begin
        fault = 1'b0;

        case (state)
            NS_GREEN: begin
                if (!(ns_green_raw && ew_red_raw &&
                      !ns_red_raw && !ns_yellow_raw &&
                      !ew_yellow_raw && !ew_green_raw))
                    fault = 1'b1;
            end
            NS_YELLOW: begin
                if (!(ns_yellow_raw && ew_red_raw &&
                      !ns_red_raw && !ns_green_raw &&
                      !ew_yellow_raw && !ew_green_raw))
                    fault = 1'b1;
            end
            ALL_RED: begin
                if (!(ns_red_raw && ew_red_raw &&
                      !ns_yellow_raw && !ns_green_raw &&
                      !ew_yellow_raw && !ew_green_raw))
                    fault = 1'b1;
            end
            EW_GREEN: begin
                if (!(ns_red_raw && ew_green_raw &&
                      !ns_yellow_raw && !ns_green_raw &&
                      !ew_red_raw && !ew_yellow_raw))
                    fault = 1'b1;
            end
            EW_YELLOW: begin
                if (!(ns_red_raw && ew_yellow_raw &&
                      !ns_yellow_raw && !ns_green_raw &&
                      !ew_red_raw && !ew_green_raw))
                    fault = 1'b1;
            end
            default: begin
                fault = 1'b1;
            end
        endcase
    end

    always @(*) begin
        if (fault) begin
            // Hard fail-safe: never expose an illegal combination.
            ns_red    = 1'b1;
            ns_yellow = 1'b0;
            ns_green  = 1'b0;
            ew_red    = 1'b1;
            ew_yellow = 1'b0;
            ew_green  = 1'b0;
        end else begin
            ns_red    = ns_red_raw;
            ns_yellow = ns_yellow_raw;
            ns_green  = ns_green_raw;
            ew_red    = ew_red_raw;
            ew_yellow = ew_yellow_raw;
            ew_green  = ew_green_raw;
        end
    end

endmodule
