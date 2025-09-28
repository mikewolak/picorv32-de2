// 4-MIF Memory Controller
// Based on proven XORO memory.v approach with MIF initialization
// Uses 4 separate 8-bit altsyncram instances for complete RISC-V compatibility

module mem_controller_4mif (
    input wire clk,
    input wire resetn,
    input wire mem_valid,
    output wire mem_ready,
    input wire mem_instr,
    input wire [3:0] mem_wstrb,
    input wire [31:0] mem_wdata,
    input wire [31:0] mem_addr,
    output wire [31:0] mem_rdata
);

    // Address and control
    wire [12:0] word_addr = mem_addr[14:2];  // Word address for 32-bit access
    wire valid_addr = (mem_addr < 32'h8000);  // 32KB memory space
    wire any_wstrb = (|mem_wstrb);
    wire is_read = (mem_valid && ~any_wstrb);
    wire is_write = (mem_valid && any_wstrb);

    // 4 separate 8-bit altsyncram instances (byte 0-3)
    wire [7:0] ram_q_byte0, ram_q_byte1, ram_q_byte2, ram_q_byte3;

    // Byte 0 (symbol 0) - altsyncram instance
    altsyncram #(
        .address_reg_b("CLOCK0"),
        .clock_enable_input_a("BYPASS"),
        .clock_enable_input_b("BYPASS"),
        .clock_enable_output_a("BYPASS"),
        .clock_enable_output_b("BYPASS"),
        .indata_reg_b("CLOCK0"),
        .init_file("firmware_symbol_0.mif"),
        .intended_device_family("Cyclone II"),
        .lpm_type("altsyncram"),
        .numwords_a(8192),               // 32KB = 8192 words
        .numwords_b(8192),
        .operation_mode("SINGLE_PORT"),
        .outdata_aclr_a("NONE"),
        .outdata_reg_a("UNREGISTERED"),  // 1 cycle latency for reads
        .power_up_uninitialized("FALSE"),
        .widthad_a(13),                  // 13 address bits for 8192 words
        .width_a(8),                     // 8-bit data width
        .width_byteena_a(1)              // 1-bit byte enable
    ) ram_byte0 (
        .clock0(clk),
        .address_a(word_addr),
        .data_a(mem_wdata[7:0]),
        .wren_a(is_write && valid_addr && mem_wstrb[0]),
        .byteena_a(1'b1),
        .q_a(ram_q_byte0),
        // Tie off unused ports
        .aclr0(1'b0), .aclr1(1'b0), .address_b(13'b0), .addressstall_a(1'b0),
        .addressstall_b(1'b0), .byteena_b(1'b1), .clock1(1'b1),
        .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
        .data_b(8'b0), .eccstatus(), .q_b(), .rden_a(1'b1), .rden_b(1'b1), .wren_b(1'b0)
    );

    // Byte 1 (symbol 1) - altsyncram instance
    altsyncram #(
        .address_reg_b("CLOCK0"),
        .clock_enable_input_a("BYPASS"),
        .clock_enable_input_b("BYPASS"),
        .clock_enable_output_a("BYPASS"),
        .clock_enable_output_b("BYPASS"),
        .indata_reg_b("CLOCK0"),
        .init_file("firmware_symbol_1.mif"),
        .intended_device_family("Cyclone II"),
        .lpm_type("altsyncram"),
        .numwords_a(8192),
        .numwords_b(8192),
        .operation_mode("SINGLE_PORT"),
        .outdata_aclr_a("NONE"),
        .outdata_reg_a("UNREGISTERED"),
        .power_up_uninitialized("FALSE"),
        .widthad_a(13),
        .width_a(8),
        .width_byteena_a(1)
    ) ram_byte1 (
        .clock0(clk),
        .address_a(word_addr),
        .data_a(mem_wdata[15:8]),
        .wren_a(is_write && valid_addr && mem_wstrb[1]),
        .byteena_a(1'b1),
        .q_a(ram_q_byte1),
        // Tie off unused ports
        .aclr0(1'b0), .aclr1(1'b0), .address_b(13'b0), .addressstall_a(1'b0),
        .addressstall_b(1'b0), .byteena_b(1'b1), .clock1(1'b1),
        .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
        .data_b(8'b0), .eccstatus(), .q_b(), .rden_a(1'b1), .rden_b(1'b1), .wren_b(1'b0)
    );

    // Byte 2 (symbol 2) - altsyncram instance
    altsyncram #(
        .address_reg_b("CLOCK0"),
        .clock_enable_input_a("BYPASS"),
        .clock_enable_input_b("BYPASS"),
        .clock_enable_output_a("BYPASS"),
        .clock_enable_output_b("BYPASS"),
        .indata_reg_b("CLOCK0"),
        .init_file("firmware_symbol_2.mif"),
        .intended_device_family("Cyclone II"),
        .lpm_type("altsyncram"),
        .numwords_a(8192),
        .numwords_b(8192),
        .operation_mode("SINGLE_PORT"),
        .outdata_aclr_a("NONE"),
        .outdata_reg_a("UNREGISTERED"),
        .power_up_uninitialized("FALSE"),
        .widthad_a(13),
        .width_a(8),
        .width_byteena_a(1)
    ) ram_byte2 (
        .clock0(clk),
        .address_a(word_addr),
        .data_a(mem_wdata[23:16]),
        .wren_a(is_write && valid_addr && mem_wstrb[2]),
        .byteena_a(1'b1),
        .q_a(ram_q_byte2),
        // Tie off unused ports
        .aclr0(1'b0), .aclr1(1'b0), .address_b(13'b0), .addressstall_a(1'b0),
        .addressstall_b(1'b0), .byteena_b(1'b1), .clock1(1'b1),
        .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
        .data_b(8'b0), .eccstatus(), .q_b(), .rden_a(1'b1), .rden_b(1'b1), .wren_b(1'b0)
    );

    // Byte 3 (symbol 3) - altsyncram instance
    altsyncram #(
        .address_reg_b("CLOCK0"),
        .clock_enable_input_a("BYPASS"),
        .clock_enable_input_b("BYPASS"),
        .clock_enable_output_a("BYPASS"),
        .clock_enable_output_b("BYPASS"),
        .indata_reg_b("CLOCK0"),
        .init_file("firmware_symbol_3.mif"),
        .intended_device_family("Cyclone II"),
        .lpm_type("altsyncram"),
        .numwords_a(8192),
        .numwords_b(8192),
        .operation_mode("SINGLE_PORT"),
        .outdata_aclr_a("NONE"),
        .outdata_reg_a("UNREGISTERED"),
        .power_up_uninitialized("FALSE"),
        .widthad_a(13),
        .width_a(8),
        .width_byteena_a(1)
    ) ram_byte3 (
        .clock0(clk),
        .address_a(word_addr),
        .data_a(mem_wdata[31:24]),
        .wren_a(is_write && valid_addr && mem_wstrb[3]),
        .byteena_a(1'b1),
        .q_a(ram_q_byte3),
        // Tie off unused ports
        .aclr0(1'b0), .aclr1(1'b0), .address_b(13'b0), .addressstall_a(1'b0),
        .addressstall_b(1'b0), .byteena_b(1'b1), .clock1(1'b1),
        .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
        .data_b(8'b0), .eccstatus(), .q_b(), .rden_a(1'b1), .rden_b(1'b1), .wren_b(1'b0)
    );

    // Timing for ALTSYNCRAM UNREGISTERED output (1-cycle latency)
    reg mem_valid_d1, is_read_d1, valid_addr_d1;

    always @(posedge clk) begin
        if (!resetn) begin
            mem_valid_d1 <= 1'b0;
            is_read_d1 <= 1'b0;
            valid_addr_d1 <= 1'b0;
        end else begin
            mem_valid_d1 <= mem_valid;
            is_read_d1 <= is_read;
            valid_addr_d1 <= valid_addr;
        end
    end

    // Ready signal: immediate for writes and invalid addresses, 1-cycle delay for reads
    assign mem_ready = (is_write && valid_addr) |                           // Writes ready immediately
                      (is_read_d1 && valid_addr_d1) |                      // Reads ready after 1 cycle
                      (mem_valid && !valid_addr);                          // Invalid addresses ready immediately

    // Assemble 32-bit read data from 4 bytes when read was valid 1 cycle ago
    assign mem_rdata = (is_read_d1 && valid_addr_d1) ?
                      {ram_q_byte3, ram_q_byte2, ram_q_byte1, ram_q_byte0} : 32'h0;

endmodule