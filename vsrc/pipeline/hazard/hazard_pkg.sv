`ifndef __HAZARD_PKG_SV
`define __HAZARD_PKG_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

`endif

package hazard_pkg;
    import common::*;

// better define them in pipes.sv(package pipes)
//    typedef struct packed {
//        logic fd, de, em, mw;
//    } regflush_en_t;
//    typedef struct packed {
//        logic fd, de, em, mw;
//    } regstall_en_t;

endpackage: hazard_pkg
`endif 