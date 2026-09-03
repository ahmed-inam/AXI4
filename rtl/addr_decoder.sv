// Combinational address -> dest_e. 4 instances (AW/AR per master port).
module addr_decoder
  import axi4_pkg::*;
(
  input  logic [ADDR_WIDTH-1:0] addr,
  output dest_e                 dest
);

  always_comb begin
    // Regions are 256MB and power-of-two aligned, so this is an upper-nibble
    // compare: no subtraction, no magnitude comparator.
    case (addr[DEC_MSB:DEC_LSB])
      S0_PREFIX: dest = DEST_S0;
      S1_PREFIX: dest = DEST_S1;
      default:   dest = DEST_DECERR;
    endcase
  end

endmodule : addr_decoder
