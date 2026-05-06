// =============================================================================
// tb_crc32.sv — Testbench do IP Core CRC-32 Low-Power
// Projeto : crc32_lowpower
// Descrição: Verifica o módulo contra vetores padrão-ouro calculados em Python
//            usando o algoritmo CRC-32 IEEE 802.3 não-refletido.
//
// Executar:
//   iverilog -g2012 -Wall -o build/sim_tb tb/tb_crc32.sv rtl/crc32_lowpower.sv
//   vvp build/sim_tb
// =============================================================================

`timescale 1ns/1ps

module tb_crc32;

    // -------------------------------------------------------------------------
    // Sinais do DUT
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic        is_last;
    logic [7:0]  data_in;
    logic        valid_out;
    logic [31:0] crc_out;

    // Contadores de teste
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // -------------------------------------------------------------------------
    // Instância do DUT
    // -------------------------------------------------------------------------
    crc32_lowpower dut (.*);

    // -------------------------------------------------------------------------
    // Clock 100 MHz (período 10 ns)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Task: aplica um pacote de bytes e verifica o CRC resultante
    // -------------------------------------------------------------------------
    task automatic run_test(
        input string         label,
        input byte           bytes[],
        input logic [31:0]   expected_crc
    );
        integer i;
        integer n = bytes.size();

        // Reset entre testes para garantir crc_reg = 0xFFFFFFFF
        rst_n = 0;
        valid_in = 0;
        is_last = 0;
        data_in = 8'h00;
        @(posedge clk); @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Envia os bytes um por ciclo
        for (i = 0; i < n; i++) begin
            valid_in = 1;
            data_in  = bytes[i];
            is_last  = (i == n - 1);
            @(posedge clk);
        end

        // Encerra o handshake
        valid_in = 0;
        is_last  = 0;
        data_in  = 8'h00;

        // Aguarda valid_out subir (FSM vai a DONE)
        wait(valid_out == 1);
        @(posedge clk); #1;

        // Verifica resultado
        if (crc_out === expected_crc) begin
            $display("[PASS] %s: CRC = 0x%08h", label, crc_out);
            pass_cnt++;
        end else begin
            $display("[FAIL] %s: CRC = 0x%08h (esperado 0x%08h)",
                     label, crc_out, expected_crc);
            fail_cnt++;
        end

        // Aguarda voltar a IDLE
        @(posedge clk); @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Vetores de teste — calculados via Python com algoritmo CRC-32 IEEE 802.3
    //                    não-refletido, polinômio 0x04C11DB7, init=0xFFFFFFFF
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("waves_crc.vcd");
        $dumpvars(0, tb_crc32);

        // Inicialização
        rst_n = 0;
        valid_in = 0;
        is_last = 0;
        data_in = 8'h00;
        repeat(4) @(posedge clk);

        $display("================================================");
        $display(" Testbench CRC-32 Low-Power");
        $display(" Polinômio: 0x04C11DB7 (IEEE 802.3, não-refletido)");
        $display(" Init:      0xFFFFFFFF");
        $display("================================================");

        // --- Teste 1: 1 byte 'A' (0x41) ---
        run_test("1 byte 'A'",
                 '{8'h41},
                 32'h7E4FD274);

        // --- Teste 2: 2 bytes 'AB' (0x41, 0x42) ---
        run_test("2 bytes 'AB'",
                 '{8'h41, 8'h42},
                 32'hAEEC82F4);

        // --- Teste 3: 3 bytes 'ABC' ---
        run_test("3 bytes 'ABC'",
                 '{8'h41, 8'h42, 8'h43},
                 32'h18E654AA);

        // --- Teste 4: vetor canônico '123456789' (9 bytes) ---
        run_test("9 bytes '123456789'",
                 '{8'h31, 8'h32, 8'h33, 8'h34, 8'h35,
                   8'h36, 8'h37, 8'h38, 8'h39},
                 32'h0376E6E7);

        // --- Teste 5: byte único 0x00 ---
        run_test("1 byte 0x00",
                 '{8'h00},
                 32'h4E08BFB4);

        // --- Teste 6: byte único 0xFF ---
        run_test("1 byte 0xFF",
                 '{8'hFF},
                 32'hFFFFFF00);

        // --- Resultado final ---
        $display("================================================");
        $display(" RESULTADO: %0d passaram, %0d falharam de 6",
                 pass_cnt, fail_cnt);
        $display("================================================");

        if (fail_cnt == 0)
            $display(" TODOS OS TESTES PASSARAM");
        else
            $display(" HÁ FALHAS — verificar formas de onda");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout de segurança — evita simulação travada
    // -------------------------------------------------------------------------
    initial begin
        #10000;
        $display("[TIMEOUT] Simulação excedeu 10us — abortando.");
        $finish;
    end

endmodule