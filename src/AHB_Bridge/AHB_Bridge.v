//-----------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from ARM Limited.
//
//            (C) COPYRIGHT 2001-2013-2026 ARM Limited.
//                ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from ARM Limited.
//
//      SVN Information
//
//      Checked In          : $Date: 2012-10-15 18:01:36 +0100 (Mon, 15 Oct 2012) $
//
//      Revision            : $Revision: 225465 $
//
//      Release Information : Cortex-M System Design Kit-r1p0-01rel0
//
//-----------------------------------------------------------------------------
//
//------------------------------------------------------------------------------
//  Abstract            : BusMatrix is the top-level which connects together
//                        the required Input Stages, MatrixDecodes, Output
//                        Stages and Output Arbitration blocks.
//
//                        Supports the following configured options:
//
//                         - Architecture type 'ahb2',
//                         - 2 slave ports (connecting to masters),
//                         - 6 master ports (connecting to slaves),
//                         - Routing address width of 32 bits,
//                         - Routing data width of 32 bits,
//                         - xUSER signal width of 32 bits,
//                         - Arbiter type 'round',
//                         - Connectivity mapping:
//                             CPU -> _PRG_RAM, _GRAPHIC_RAM, _APB, _NES_RAM, _SDCARD, _ETHERNET,
//                             NES -> _NES_RAM,
//                         - Connectivity type 'sparse'.
//
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module AHB_Bridge (

    // Common AHB signals
    HCLK,
    HRESETn,

    // System address remapping control
    REMAP,

    // Input port SI0 (inputs from master 0)
    HSELCPU,
    HADDRCPU,
    HTRANSCPU,
    HWRITECPU,
    HSIZECPU,
    HBURSTCPU,
    HPROTCPU,
    HMASTERCPU,
    HWDATACPU,
    HMASTLOCKCPU,
    HREADYCPU,
    HAUSERCPU,
    HWUSERCPU,

    // Input port SI1 (inputs from master 1)
    HSELNES,
    HADDRNES,
    HTRANSNES,
    HWRITENES,
    HSIZENES,
    HBURSTNES,
    HPROTNES,
    HMASTERNES,
    HWDATANES,
    HMASTLOCKNES,
    HREADYNES,
    HAUSERNES,
    HWUSERNES,

    // Output port MI0 (inputs from slave 0)
    HRDATA_PRG_RAM,
    HREADYOUT_PRG_RAM,
    HRESP_PRG_RAM,
    HRUSER_PRG_RAM,

    // Output port MI1 (inputs from slave 1)
    HRDATA_GRAPHIC_RAM,
    HREADYOUT_GRAPHIC_RAM,
    HRESP_GRAPHIC_RAM,
    HRUSER_GRAPHIC_RAM,

    // Output port MI2 (inputs from slave 2)
    HRDATA_APB,
    HREADYOUT_APB,
    HRESP_APB,
    HRUSER_APB,

    // Output port MI3 (inputs from slave 3)
    HRDATA_NES_RAM,
    HREADYOUT_NES_RAM,
    HRESP_NES_RAM,
    HRUSER_NES_RAM,

    // Output port MI4 (inputs from slave 4)
    HRDATA_SDCARD,
    HREADYOUT_SDCARD,
    HRESP_SDCARD,
    HRUSER_SDCARD,

    // Output port MI5 (inputs from slave 5)
    HRDATA_ETHERNET,
    HREADYOUT_ETHERNET,
    HRESP_ETHERNET,
    HRUSER_ETHERNET,

    // Scan test dummy signals; not connected until scan insertion
    SCANENABLE,   // Scan Test Mode Enable
    SCANINHCLK,   // Scan Chain Input


    // Output port MI0 (outputs to slave 0)
    HSEL_PRG_RAM,
    HADDR_PRG_RAM,
    HTRANS_PRG_RAM,
    HWRITE_PRG_RAM,
    HSIZE_PRG_RAM,
    HBURST_PRG_RAM,
    HPROT_PRG_RAM,
    HMASTER_PRG_RAM,
    HWDATA_PRG_RAM,
    HMASTLOCK_PRG_RAM,
    HREADYMUX_PRG_RAM,
    HAUSER_PRG_RAM,
    HWUSER_PRG_RAM,

    // Output port MI1 (outputs to slave 1)
    HSEL_GRAPHIC_RAM,
    HADDR_GRAPHIC_RAM,
    HTRANS_GRAPHIC_RAM,
    HWRITE_GRAPHIC_RAM,
    HSIZE_GRAPHIC_RAM,
    HBURST_GRAPHIC_RAM,
    HPROT_GRAPHIC_RAM,
    HMASTER_GRAPHIC_RAM,
    HWDATA_GRAPHIC_RAM,
    HMASTLOCK_GRAPHIC_RAM,
    HREADYMUX_GRAPHIC_RAM,
    HAUSER_GRAPHIC_RAM,
    HWUSER_GRAPHIC_RAM,

    // Output port MI2 (outputs to slave 2)
    HSEL_APB,
    HADDR_APB,
    HTRANS_APB,
    HWRITE_APB,
    HSIZE_APB,
    HBURST_APB,
    HPROT_APB,
    HMASTER_APB,
    HWDATA_APB,
    HMASTLOCK_APB,
    HREADYMUX_APB,
    HAUSER_APB,
    HWUSER_APB,

    // Output port MI3 (outputs to slave 3)
    HSEL_NES_RAM,
    HADDR_NES_RAM,
    HTRANS_NES_RAM,
    HWRITE_NES_RAM,
    HSIZE_NES_RAM,
    HBURST_NES_RAM,
    HPROT_NES_RAM,
    HMASTER_NES_RAM,
    HWDATA_NES_RAM,
    HMASTLOCK_NES_RAM,
    HREADYMUX_NES_RAM,
    HAUSER_NES_RAM,
    HWUSER_NES_RAM,

    // Output port MI4 (outputs to slave 4)
    HSEL_SDCARD,
    HADDR_SDCARD,
    HTRANS_SDCARD,
    HWRITE_SDCARD,
    HSIZE_SDCARD,
    HBURST_SDCARD,
    HPROT_SDCARD,
    HMASTER_SDCARD,
    HWDATA_SDCARD,
    HMASTLOCK_SDCARD,
    HREADYMUX_SDCARD,
    HAUSER_SDCARD,
    HWUSER_SDCARD,

    // Output port MI5 (outputs to slave 5)
    HSEL_ETHERNET,
    HADDR_ETHERNET,
    HTRANS_ETHERNET,
    HWRITE_ETHERNET,
    HSIZE_ETHERNET,
    HBURST_ETHERNET,
    HPROT_ETHERNET,
    HMASTER_ETHERNET,
    HWDATA_ETHERNET,
    HMASTLOCK_ETHERNET,
    HREADYMUX_ETHERNET,
    HAUSER_ETHERNET,
    HWUSER_ETHERNET,

    // Input port SI0 (outputs to master 0)
    HRDATACPU,
    HREADYOUTCPU,
    HRESPCPU,
    HRUSERCPU,

    // Input port SI1 (outputs to master 1)
    HRDATANES,
    HREADYOUTNES,
    HRESPNES,
    HRUSERNES,

    // Scan test dummy signals; not connected until scan insertion
    SCANOUTHCLK   // Scan Chain Output

    );


// -----------------------------------------------------------------------------
// Input and Output declarations
// -----------------------------------------------------------------------------

    // Common AHB signals
    input         HCLK;            // AHB System Clock
    input         HRESETn;         // AHB System Reset

    // System address remapping control
    input   [3:0] REMAP;           // REMAP input

    // Input port SI0 (inputs from master 0)
    input         HSELCPU;          // Slave Select
    input  [31:0] HADDRCPU;         // Address bus
    input   [1:0] HTRANSCPU;        // Transfer type
    input         HWRITECPU;        // Transfer direction
    input   [2:0] HSIZECPU;         // Transfer size
    input   [2:0] HBURSTCPU;        // Burst type
    input   [3:0] HPROTCPU;         // Protection control
    input   [3:0] HMASTERCPU;       // Master select
    input  [31:0] HWDATACPU;        // Write data
    input         HMASTLOCKCPU;     // Locked Sequence
    input         HREADYCPU;        // Transfer done
    input  [31:0] HAUSERCPU;        // Address USER signals
    input  [31:0] HWUSERCPU;        // Write-data USER signals

    // Input port SI1 (inputs from master 1)
    input         HSELNES;          // Slave Select
    input  [31:0] HADDRNES;         // Address bus
    input   [1:0] HTRANSNES;        // Transfer type
    input         HWRITENES;        // Transfer direction
    input   [2:0] HSIZENES;         // Transfer size
    input   [2:0] HBURSTNES;        // Burst type
    input   [3:0] HPROTNES;         // Protection control
    input   [3:0] HMASTERNES;       // Master select
    input  [31:0] HWDATANES;        // Write data
    input         HMASTLOCKNES;     // Locked Sequence
    input         HREADYNES;        // Transfer done
    input  [31:0] HAUSERNES;        // Address USER signals
    input  [31:0] HWUSERNES;        // Write-data USER signals

    // Output port MI0 (inputs from slave 0)
    input  [31:0] HRDATA_PRG_RAM;        // Read data bus
    input         HREADYOUT_PRG_RAM;     // HREADY feedback
    input   [1:0] HRESP_PRG_RAM;         // Transfer response
    input  [31:0] HRUSER_PRG_RAM;        // Read-data USER signals

    // Output port MI1 (inputs from slave 1)
    input  [31:0] HRDATA_GRAPHIC_RAM;        // Read data bus
    input         HREADYOUT_GRAPHIC_RAM;     // HREADY feedback
    input   [1:0] HRESP_GRAPHIC_RAM;         // Transfer response
    input  [31:0] HRUSER_GRAPHIC_RAM;        // Read-data USER signals

    // Output port MI2 (inputs from slave 2)
    input  [31:0] HRDATA_APB;        // Read data bus
    input         HREADYOUT_APB;     // HREADY feedback
    input   [1:0] HRESP_APB;         // Transfer response
    input  [31:0] HRUSER_APB;        // Read-data USER signals

    // Output port MI3 (inputs from slave 3)
    input  [31:0] HRDATA_NES_RAM;        // Read data bus
    input         HREADYOUT_NES_RAM;     // HREADY feedback
    input   [1:0] HRESP_NES_RAM;         // Transfer response
    input  [31:0] HRUSER_NES_RAM;        // Read-data USER signals

    // Output port MI4 (inputs from slave 4)
    input  [31:0] HRDATA_SDCARD;        // Read data bus
    input         HREADYOUT_SDCARD;     // HREADY feedback
    input   [1:0] HRESP_SDCARD;         // Transfer response
    input  [31:0] HRUSER_SDCARD;        // Read-data USER signals

    // Output port MI5 (inputs from slave 5)
    input  [31:0] HRDATA_ETHERNET;        // Read data bus
    input         HREADYOUT_ETHERNET;     // HREADY feedback
    input   [1:0] HRESP_ETHERNET;         // Transfer response
    input  [31:0] HRUSER_ETHERNET;        // Read-data USER signals

    // Scan test dummy signals; not connected until scan insertion
    input         SCANENABLE;      // Scan enable signal
    input         SCANINHCLK;      // HCLK scan input


    // Output port MI0 (outputs to slave 0)
    output        HSEL_PRG_RAM;          // Slave Select
    output [31:0] HADDR_PRG_RAM;         // Address bus
    output  [1:0] HTRANS_PRG_RAM;        // Transfer type
    output        HWRITE_PRG_RAM;        // Transfer direction
    output  [2:0] HSIZE_PRG_RAM;         // Transfer size
    output  [2:0] HBURST_PRG_RAM;        // Burst type
    output  [3:0] HPROT_PRG_RAM;         // Protection control
    output  [3:0] HMASTER_PRG_RAM;       // Master select
    output [31:0] HWDATA_PRG_RAM;        // Write data
    output        HMASTLOCK_PRG_RAM;     // Locked Sequence
    output        HREADYMUX_PRG_RAM;     // Transfer done
    output [31:0] HAUSER_PRG_RAM;        // Address USER signals
    output [31:0] HWUSER_PRG_RAM;        // Write-data USER signals

    // Output port MI1 (outputs to slave 1)
    output        HSEL_GRAPHIC_RAM;          // Slave Select
    output [31:0] HADDR_GRAPHIC_RAM;         // Address bus
    output  [1:0] HTRANS_GRAPHIC_RAM;        // Transfer type
    output        HWRITE_GRAPHIC_RAM;        // Transfer direction
    output  [2:0] HSIZE_GRAPHIC_RAM;         // Transfer size
    output  [2:0] HBURST_GRAPHIC_RAM;        // Burst type
    output  [3:0] HPROT_GRAPHIC_RAM;         // Protection control
    output  [3:0] HMASTER_GRAPHIC_RAM;       // Master select
    output [31:0] HWDATA_GRAPHIC_RAM;        // Write data
    output        HMASTLOCK_GRAPHIC_RAM;     // Locked Sequence
    output        HREADYMUX_GRAPHIC_RAM;     // Transfer done
    output [31:0] HAUSER_GRAPHIC_RAM;        // Address USER signals
    output [31:0] HWUSER_GRAPHIC_RAM;        // Write-data USER signals

    // Output port MI2 (outputs to slave 2)
    output        HSEL_APB;          // Slave Select
    output [31:0] HADDR_APB;         // Address bus
    output  [1:0] HTRANS_APB;        // Transfer type
    output        HWRITE_APB;        // Transfer direction
    output  [2:0] HSIZE_APB;         // Transfer size
    output  [2:0] HBURST_APB;        // Burst type
    output  [3:0] HPROT_APB;         // Protection control
    output  [3:0] HMASTER_APB;       // Master select
    output [31:0] HWDATA_APB;        // Write data
    output        HMASTLOCK_APB;     // Locked Sequence
    output        HREADYMUX_APB;     // Transfer done
    output [31:0] HAUSER_APB;        // Address USER signals
    output [31:0] HWUSER_APB;        // Write-data USER signals

    // Output port MI3 (outputs to slave 3)
    output        HSEL_NES_RAM;          // Slave Select
    output [31:0] HADDR_NES_RAM;         // Address bus
    output  [1:0] HTRANS_NES_RAM;        // Transfer type
    output        HWRITE_NES_RAM;        // Transfer direction
    output  [2:0] HSIZE_NES_RAM;         // Transfer size
    output  [2:0] HBURST_NES_RAM;        // Burst type
    output  [3:0] HPROT_NES_RAM;         // Protection control
    output  [3:0] HMASTER_NES_RAM;       // Master select
    output [31:0] HWDATA_NES_RAM;        // Write data
    output        HMASTLOCK_NES_RAM;     // Locked Sequence
    output        HREADYMUX_NES_RAM;     // Transfer done
    output [31:0] HAUSER_NES_RAM;        // Address USER signals
    output [31:0] HWUSER_NES_RAM;        // Write-data USER signals

    // Output port MI4 (outputs to slave 4)
    output        HSEL_SDCARD;          // Slave Select
    output [31:0] HADDR_SDCARD;         // Address bus
    output  [1:0] HTRANS_SDCARD;        // Transfer type
    output        HWRITE_SDCARD;        // Transfer direction
    output  [2:0] HSIZE_SDCARD;         // Transfer size
    output  [2:0] HBURST_SDCARD;        // Burst type
    output  [3:0] HPROT_SDCARD;         // Protection control
    output  [3:0] HMASTER_SDCARD;       // Master select
    output [31:0] HWDATA_SDCARD;        // Write data
    output        HMASTLOCK_SDCARD;     // Locked Sequence
    output        HREADYMUX_SDCARD;     // Transfer done
    output [31:0] HAUSER_SDCARD;        // Address USER signals
    output [31:0] HWUSER_SDCARD;        // Write-data USER signals

    // Output port MI5 (outputs to slave 5)
    output        HSEL_ETHERNET;          // Slave Select
    output [31:0] HADDR_ETHERNET;         // Address bus
    output  [1:0] HTRANS_ETHERNET;        // Transfer type
    output        HWRITE_ETHERNET;        // Transfer direction
    output  [2:0] HSIZE_ETHERNET;         // Transfer size
    output  [2:0] HBURST_ETHERNET;        // Burst type
    output  [3:0] HPROT_ETHERNET;         // Protection control
    output  [3:0] HMASTER_ETHERNET;       // Master select
    output [31:0] HWDATA_ETHERNET;        // Write data
    output        HMASTLOCK_ETHERNET;     // Locked Sequence
    output        HREADYMUX_ETHERNET;     // Transfer done
    output [31:0] HAUSER_ETHERNET;        // Address USER signals
    output [31:0] HWUSER_ETHERNET;        // Write-data USER signals

    // Input port SI0 (outputs to master 0)
    output [31:0] HRDATACPU;        // Read data bus
    output        HREADYOUTCPU;     // HREADY feedback
    output  [1:0] HRESPCPU;         // Transfer response
    output [31:0] HRUSERCPU;        // Read-data USER signals

    // Input port SI1 (outputs to master 1)
    output [31:0] HRDATANES;        // Read data bus
    output        HREADYOUTNES;     // HREADY feedback
    output  [1:0] HRESPNES;         // Transfer response
    output [31:0] HRUSERNES;        // Read-data USER signals

    // Scan test dummy signals; not connected until scan insertion
    output        SCANOUTHCLK;     // Scan Chain Output


// -----------------------------------------------------------------------------
// Wire declarations
// -----------------------------------------------------------------------------

    // Common AHB signals
    wire         HCLK;            // AHB System Clock
    wire         HRESETn;         // AHB System Reset

    // System address remapping control
    wire   [3:0] REMAP;           // REMAP signal

    // Input Port SI0
    wire         HSELCPU;          // Slave Select
    wire  [31:0] HADDRCPU;         // Address bus
    wire   [1:0] HTRANSCPU;        // Transfer type
    wire         HWRITECPU;        // Transfer direction
    wire   [2:0] HSIZECPU;         // Transfer size
    wire   [2:0] HBURSTCPU;        // Burst type
    wire   [3:0] HPROTCPU;         // Protection control
    wire   [3:0] HMASTERCPU;       // Master select
    wire  [31:0] HWDATACPU;        // Write data
    wire         HMASTLOCKCPU;     // Locked Sequence
    wire         HREADYCPU;        // Transfer done

    wire  [31:0] HRDATACPU;        // Read data bus
    wire         HREADYOUTCPU;     // HREADY feedback
    wire   [1:0] HRESPCPU;         // Transfer response
    wire  [31:0] HAUSERCPU;        // Address USER signals
    wire  [31:0] HWUSERCPU;        // Write-data USER signals
    wire  [31:0] HRUSERCPU;        // Read-data USER signals

    // Input Port SI1
    wire         HSELNES;          // Slave Select
    wire  [31:0] HADDRNES;         // Address bus
    wire   [1:0] HTRANSNES;        // Transfer type
    wire         HWRITENES;        // Transfer direction
    wire   [2:0] HSIZENES;         // Transfer size
    wire   [2:0] HBURSTNES;        // Burst type
    wire   [3:0] HPROTNES;         // Protection control
    wire   [3:0] HMASTERNES;       // Master select
    wire  [31:0] HWDATANES;        // Write data
    wire         HMASTLOCKNES;     // Locked Sequence
    wire         HREADYNES;        // Transfer done

    wire  [31:0] HRDATANES;        // Read data bus
    wire         HREADYOUTNES;     // HREADY feedback
    wire   [1:0] HRESPNES;         // Transfer response
    wire  [31:0] HAUSERNES;        // Address USER signals
    wire  [31:0] HWUSERNES;        // Write-data USER signals
    wire  [31:0] HRUSERNES;        // Read-data USER signals

    // Output Port MI0
    wire         HSEL_PRG_RAM;          // Slave Select
    wire  [31:0] HADDR_PRG_RAM;         // Address bus
    wire   [1:0] HTRANS_PRG_RAM;        // Transfer type
    wire         HWRITE_PRG_RAM;        // Transfer direction
    wire   [2:0] HSIZE_PRG_RAM;         // Transfer size
    wire   [2:0] HBURST_PRG_RAM;        // Burst type
    wire   [3:0] HPROT_PRG_RAM;         // Protection control
    wire   [3:0] HMASTER_PRG_RAM;       // Master select
    wire  [31:0] HWDATA_PRG_RAM;        // Write data
    wire         HMASTLOCK_PRG_RAM;     // Locked Sequence
    wire         HREADYMUX_PRG_RAM;     // Transfer done

    wire  [31:0] HRDATA_PRG_RAM;        // Read data bus
    wire         HREADYOUT_PRG_RAM;     // HREADY feedback
    wire   [1:0] HRESP_PRG_RAM;         // Transfer response
    wire  [31:0] HAUSER_PRG_RAM;        // Address USER signals
    wire  [31:0] HWUSER_PRG_RAM;        // Write-data USER signals
    wire  [31:0] HRUSER_PRG_RAM;        // Read-data USER signals

    // Output Port MI1
    wire         HSEL_GRAPHIC_RAM;          // Slave Select
    wire  [31:0] HADDR_GRAPHIC_RAM;         // Address bus
    wire   [1:0] HTRANS_GRAPHIC_RAM;        // Transfer type
    wire         HWRITE_GRAPHIC_RAM;        // Transfer direction
    wire   [2:0] HSIZE_GRAPHIC_RAM;         // Transfer size
    wire   [2:0] HBURST_GRAPHIC_RAM;        // Burst type
    wire   [3:0] HPROT_GRAPHIC_RAM;         // Protection control
    wire   [3:0] HMASTER_GRAPHIC_RAM;       // Master select
    wire  [31:0] HWDATA_GRAPHIC_RAM;        // Write data
    wire         HMASTLOCK_GRAPHIC_RAM;     // Locked Sequence
    wire         HREADYMUX_GRAPHIC_RAM;     // Transfer done

    wire  [31:0] HRDATA_GRAPHIC_RAM;        // Read data bus
    wire         HREADYOUT_GRAPHIC_RAM;     // HREADY feedback
    wire   [1:0] HRESP_GRAPHIC_RAM;         // Transfer response
    wire  [31:0] HAUSER_GRAPHIC_RAM;        // Address USER signals
    wire  [31:0] HWUSER_GRAPHIC_RAM;        // Write-data USER signals
    wire  [31:0] HRUSER_GRAPHIC_RAM;        // Read-data USER signals

    // Output Port MI2
    wire         HSEL_APB;          // Slave Select
    wire  [31:0] HADDR_APB;         // Address bus
    wire   [1:0] HTRANS_APB;        // Transfer type
    wire         HWRITE_APB;        // Transfer direction
    wire   [2:0] HSIZE_APB;         // Transfer size
    wire   [2:0] HBURST_APB;        // Burst type
    wire   [3:0] HPROT_APB;         // Protection control
    wire   [3:0] HMASTER_APB;       // Master select
    wire  [31:0] HWDATA_APB;        // Write data
    wire         HMASTLOCK_APB;     // Locked Sequence
    wire         HREADYMUX_APB;     // Transfer done

    wire  [31:0] HRDATA_APB;        // Read data bus
    wire         HREADYOUT_APB;     // HREADY feedback
    wire   [1:0] HRESP_APB;         // Transfer response
    wire  [31:0] HAUSER_APB;        // Address USER signals
    wire  [31:0] HWUSER_APB;        // Write-data USER signals
    wire  [31:0] HRUSER_APB;        // Read-data USER signals

    // Output Port MI3
    wire         HSEL_NES_RAM;          // Slave Select
    wire  [31:0] HADDR_NES_RAM;         // Address bus
    wire   [1:0] HTRANS_NES_RAM;        // Transfer type
    wire         HWRITE_NES_RAM;        // Transfer direction
    wire   [2:0] HSIZE_NES_RAM;         // Transfer size
    wire   [2:0] HBURST_NES_RAM;        // Burst type
    wire   [3:0] HPROT_NES_RAM;         // Protection control
    wire   [3:0] HMASTER_NES_RAM;       // Master select
    wire  [31:0] HWDATA_NES_RAM;        // Write data
    wire         HMASTLOCK_NES_RAM;     // Locked Sequence
    wire         HREADYMUX_NES_RAM;     // Transfer done

    wire  [31:0] HRDATA_NES_RAM;        // Read data bus
    wire         HREADYOUT_NES_RAM;     // HREADY feedback
    wire   [1:0] HRESP_NES_RAM;         // Transfer response
    wire  [31:0] HAUSER_NES_RAM;        // Address USER signals
    wire  [31:0] HWUSER_NES_RAM;        // Write-data USER signals
    wire  [31:0] HRUSER_NES_RAM;        // Read-data USER signals

    // Output Port MI4
    wire         HSEL_SDCARD;          // Slave Select
    wire  [31:0] HADDR_SDCARD;         // Address bus
    wire   [1:0] HTRANS_SDCARD;        // Transfer type
    wire         HWRITE_SDCARD;        // Transfer direction
    wire   [2:0] HSIZE_SDCARD;         // Transfer size
    wire   [2:0] HBURST_SDCARD;        // Burst type
    wire   [3:0] HPROT_SDCARD;         // Protection control
    wire   [3:0] HMASTER_SDCARD;       // Master select
    wire  [31:0] HWDATA_SDCARD;        // Write data
    wire         HMASTLOCK_SDCARD;     // Locked Sequence
    wire         HREADYMUX_SDCARD;     // Transfer done

    wire  [31:0] HRDATA_SDCARD;        // Read data bus
    wire         HREADYOUT_SDCARD;     // HREADY feedback
    wire   [1:0] HRESP_SDCARD;         // Transfer response
    wire  [31:0] HAUSER_SDCARD;        // Address USER signals
    wire  [31:0] HWUSER_SDCARD;        // Write-data USER signals
    wire  [31:0] HRUSER_SDCARD;        // Read-data USER signals

    // Output Port MI5
    wire         HSEL_ETHERNET;          // Slave Select
    wire  [31:0] HADDR_ETHERNET;         // Address bus
    wire   [1:0] HTRANS_ETHERNET;        // Transfer type
    wire         HWRITE_ETHERNET;        // Transfer direction
    wire   [2:0] HSIZE_ETHERNET;         // Transfer size
    wire   [2:0] HBURST_ETHERNET;        // Burst type
    wire   [3:0] HPROT_ETHERNET;         // Protection control
    wire   [3:0] HMASTER_ETHERNET;       // Master select
    wire  [31:0] HWDATA_ETHERNET;        // Write data
    wire         HMASTLOCK_ETHERNET;     // Locked Sequence
    wire         HREADYMUX_ETHERNET;     // Transfer done

    wire  [31:0] HRDATA_ETHERNET;        // Read data bus
    wire         HREADYOUT_ETHERNET;     // HREADY feedback
    wire   [1:0] HRESP_ETHERNET;         // Transfer response
    wire  [31:0] HAUSER_ETHERNET;        // Address USER signals
    wire  [31:0] HWUSER_ETHERNET;        // Write-data USER signals
    wire  [31:0] HRUSER_ETHERNET;        // Read-data USER signals


// -----------------------------------------------------------------------------
// Signal declarations
// -----------------------------------------------------------------------------

    // Bus-switch input SI0
    wire         i_sel0;            // HSEL signal
    wire  [31:0] i_addr0;           // HADDR signal
    wire   [1:0] i_trans0;          // HTRANS signal
    wire         i_write0;          // HWRITE signal
    wire   [2:0] i_size0;           // HSIZE signal
    wire   [2:0] i_burst0;          // HBURST signal
    wire   [3:0] i_prot0;           // HPROTS signal
    wire   [3:0] i_master0;         // HMASTER signal
    wire         i_mastlock0;       // HMASTLOCK signal
    wire         i_active0;         // Active signal
    wire         i_held_tran0;       // HeldTran signal
    wire         i_readyout0;       // Readyout signal
    wire   [1:0] i_resp0;           // Response signal
    wire  [31:0] i_auser0;          // HAUSER signal

    // Bus-switch input SI1
    wire         i_sel1;            // HSEL signal
    wire  [31:0] i_addr1;           // HADDR signal
    wire   [1:0] i_trans1;          // HTRANS signal
    wire         i_write1;          // HWRITE signal
    wire   [2:0] i_size1;           // HSIZE signal
    wire   [2:0] i_burst1;          // HBURST signal
    wire   [3:0] i_prot1;           // HPROTS signal
    wire   [3:0] i_master1;         // HMASTER signal
    wire         i_mastlock1;       // HMASTLOCK signal
    wire         i_active1;         // Active signal
    wire         i_held_tran1;       // HeldTran signal
    wire         i_readyout1;       // Readyout signal
    wire   [1:0] i_resp1;           // Response signal
    wire  [31:0] i_auser1;          // HAUSER signal

    // Bus-switch SI0 to MI0 signals
    wire         i_sel0to0;         // Routing selection signal
    wire         i_active0to0;      // Active signal

    // Bus-switch SI0 to MI1 signals
    wire         i_sel0to1;         // Routing selection signal
    wire         i_active0to1;      // Active signal

    // Bus-switch SI0 to MI2 signals
    wire         i_sel0to2;         // Routing selection signal
    wire         i_active0to2;      // Active signal

    // Bus-switch SI0 to MI3 signals
    wire         i_sel0to3;         // Routing selection signal
    wire         i_active0to3;      // Active signal

    // Bus-switch SI0 to MI4 signals
    wire         i_sel0to4;         // Routing selection signal
    wire         i_active0to4;      // Active signal

    // Bus-switch SI0 to MI5 signals
    wire         i_sel0to5;         // Routing selection signal
    wire         i_active0to5;      // Active signal

    // Bus-switch SI1 to MI3 signals
    wire         i_sel1to3;         // Routing selection signal
    wire         i_active1to3;      // Active signal

    wire         i_hready_mux__prg_ram;    // Internal HREADYMUXM for MI0
    wire         i_hready_mux__graphic_ram;    // Internal HREADYMUXM for MI1
    wire         i_hready_mux__apb;    // Internal HREADYMUXM for MI2
    wire         i_hready_mux__nes_ram;    // Internal HREADYMUXM for MI3
    wire         i_hready_mux__sdcard;    // Internal HREADYMUXM for MI4
    wire         i_hready_mux__ethernet;    // Internal HREADYMUXM for MI5


// -----------------------------------------------------------------------------
// Beginning of main code
// -----------------------------------------------------------------------------

  // Input stage for SI0
  Input_Stage u_Input_Stage_0 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Input Port Address/Control Signals
    .HSELS      (HSELCPU),
    .HADDRS     (HADDRCPU),
    .HTRANSS    (HTRANSCPU),
    .HWRITES    (HWRITECPU),
    .HSIZES     (HSIZECPU),
    .HBURSTS    (HBURSTCPU),
    .HPROTS     (HPROTCPU),
    .HMASTERS   (HMASTERCPU),
    .HMASTLOCKS (HMASTLOCKCPU),
    .HREADYS    (HREADYCPU),
    .HAUSERS    (HAUSERCPU),

    // Internal Response
    .active_ip     (i_active0),
    .readyout_ip   (i_readyout0),
    .resp_ip       (i_resp0),

    // Input Port Response
    .HREADYOUTS (HREADYOUTCPU),
    .HRESPS     (HRESPCPU),

    // Internal Address/Control Signals
    .sel_ip        (i_sel0),
    .addr_ip       (i_addr0),
    .auser_ip      (i_auser0),
    .trans_ip      (i_trans0),
    .write_ip      (i_write0),
    .size_ip       (i_size0),
    .burst_ip      (i_burst0),
    .prot_ip       (i_prot0),
    .master_ip     (i_master0),
    .mastlock_ip   (i_mastlock0),
    .held_tran_ip   (i_held_tran0)

    );


  // Input stage for SI1
  Input_Stage u_Input_Stage_1 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Input Port Address/Control Signals
    .HSELS      (HSELNES),
    .HADDRS     (HADDRNES),
    .HTRANSS    (HTRANSNES),
    .HWRITES    (HWRITENES),
    .HSIZES     (HSIZENES),
    .HBURSTS    (HBURSTNES),
    .HPROTS     (HPROTNES),
    .HMASTERS   (HMASTERNES),
    .HMASTLOCKS (HMASTLOCKNES),
    .HREADYS    (HREADYNES),
    .HAUSERS    (HAUSERNES),

    // Internal Response
    .active_ip     (i_active1),
    .readyout_ip   (i_readyout1),
    .resp_ip       (i_resp1),

    // Input Port Response
    .HREADYOUTS (HREADYOUTNES),
    .HRESPS     (HRESPNES),

    // Internal Address/Control Signals
    .sel_ip        (i_sel1),
    .addr_ip       (i_addr1),
    .auser_ip      (i_auser1),
    .trans_ip      (i_trans1),
    .write_ip      (i_write1),
    .size_ip       (i_size1),
    .burst_ip      (i_burst1),
    .prot_ip       (i_prot1),
    .master_ip     (i_master1),
    .mastlock_ip   (i_mastlock1),
    .held_tran_ip   (i_held_tran1)

    );


  // Matrix decoder for SI0
  AHB_Bridge_DecoderCPU u_ahb_bridge_decodercpu (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Signals from Input stage SI0
    .HREADYS    (HREADYCPU),
    .sel_dec        (i_sel0),
    .decode_addr_dec (i_addr0[31:10]),   // HADDR[9:0] is not decoded
    .trans_dec      (i_trans0),

    // Control/Response for Output Stage MI0
    .active_dec0    (i_active0to0),
    .readyout_dec0  (i_hready_mux__prg_ram),
    .resp_dec0      (HRESP_PRG_RAM),
    .rdata_dec0     (HRDATA_PRG_RAM),
    .ruser_dec0     (HRUSER_PRG_RAM),

    // Control/Response for Output Stage MI1
    .active_dec1    (i_active0to1),
    .readyout_dec1  (i_hready_mux__graphic_ram),
    .resp_dec1      (HRESP_GRAPHIC_RAM),
    .rdata_dec1     (HRDATA_GRAPHIC_RAM),
    .ruser_dec1     (HRUSER_GRAPHIC_RAM),

    // Control/Response for Output Stage MI2
    .active_dec2    (i_active0to2),
    .readyout_dec2  (i_hready_mux__apb),
    .resp_dec2      (HRESP_APB),
    .rdata_dec2     (HRDATA_APB),
    .ruser_dec2     (HRUSER_APB),

    // Control/Response for Output Stage MI3
    .active_dec3    (i_active0to3),
    .readyout_dec3  (i_hready_mux__nes_ram),
    .resp_dec3      (HRESP_NES_RAM),
    .rdata_dec3     (HRDATA_NES_RAM),
    .ruser_dec3     (HRUSER_NES_RAM),

    // Control/Response for Output Stage MI4
    .active_dec4    (i_active0to4),
    .readyout_dec4  (i_hready_mux__sdcard),
    .resp_dec4      (HRESP_SDCARD),
    .rdata_dec4     (HRDATA_SDCARD),
    .ruser_dec4     (HRUSER_SDCARD),

    // Control/Response for Output Stage MI5
    .active_dec5    (i_active0to5),
    .readyout_dec5  (i_hready_mux__ethernet),
    .resp_dec5      (HRESP_ETHERNET),
    .rdata_dec5     (HRDATA_ETHERNET),
    .ruser_dec5     (HRUSER_ETHERNET),

    .sel_dec0       (i_sel0to0),
    .sel_dec1       (i_sel0to1),
    .sel_dec2       (i_sel0to2),
    .sel_dec3       (i_sel0to3),
    .sel_dec4       (i_sel0to4),
    .sel_dec5       (i_sel0to5),

    .active_dec     (i_active0),
    .HREADYOUTS (i_readyout0),
    .HRESPS     (i_resp0),
    .HRUSERS    (HRUSERCPU),
    .HRDATAS    (HRDATACPU)

    );


  // Matrix decoder for SI1
  AHB_Bridge_DecoderNES u_ahb_bridge_decodernes (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Signals from Input stage SI1
    .HREADYS    (HREADYNES),
    .sel_dec        (i_sel1),
    .decode_addr_dec (i_addr1[31:10]),   // HADDR[9:0] is not decoded
    .trans_dec      (i_trans1),

    // Control/Response for Output Stage MI3
    .active_dec3    (i_active1to3),
    .readyout_dec3  (i_hready_mux__nes_ram),
    .resp_dec3      (HRESP_NES_RAM),
    .rdata_dec3     (HRDATA_NES_RAM),
    .ruser_dec3     (HRUSER_NES_RAM),

    .sel_dec3       (i_sel1to3),

    .active_dec     (i_active1),
    .HREADYOUTS (i_readyout1),
    .HRESPS     (i_resp1),
    .HRUSERS    (HRUSERNES),
    .HRDATAS    (HRDATANES)

    );


  // Output stage for MI0
  Output_Stage_PRG_RAM u_output_stage_prg_ram_0 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Port 0 Signals
    .sel_op0       (i_sel0to0),
    .addr_op0      (i_addr0),
    .auser_op0     (i_auser0),
    .trans_op0     (i_trans0),
    .write_op0     (i_write0),
    .size_op0      (i_size0),
    .burst_op0     (i_burst0),
    .prot_op0      (i_prot0),
    .master_op0    (i_master0),
    .mastlock_op0  (i_mastlock0),
    .wdata_op0     (HWDATACPU),
    .wuser_op0     (HWUSERCPU),
    .held_tran_op0  (i_held_tran0),

    // Slave read data and response
    .HREADYOUTM (HREADYOUT_PRG_RAM),

    .active_op0    (i_active0to0),

    // Slave Address/Control Signals
    .HSELM      (HSEL_PRG_RAM),
    .HADDRM     (HADDR_PRG_RAM),
    .HAUSERM    (HAUSER_PRG_RAM),
    .HTRANSM    (HTRANS_PRG_RAM),
    .HWRITEM    (HWRITE_PRG_RAM),
    .HSIZEM     (HSIZE_PRG_RAM),
    .HBURSTM    (HBURST_PRG_RAM),
    .HPROTM     (HPROT_PRG_RAM),
    .HMASTERM   (HMASTER_PRG_RAM),
    .HMASTLOCKM (HMASTLOCK_PRG_RAM),
    .HREADYMUXM (i_hready_mux__prg_ram),
    .HWUSERM    (HWUSER_PRG_RAM),
    .HWDATAM    (HWDATA_PRG_RAM)

    );

  // Drive output with internal version
  assign HREADYMUX_PRG_RAM = i_hready_mux__prg_ram;


  // Output stage for MI1
  Output_Stage_GRAPHIC_RAM u_output_stage_graphic_ram_1 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Port 0 Signals
    .sel_op0       (i_sel0to1),
    .addr_op0      (i_addr0),
    .auser_op0     (i_auser0),
    .trans_op0     (i_trans0),
    .write_op0     (i_write0),
    .size_op0      (i_size0),
    .burst_op0     (i_burst0),
    .prot_op0      (i_prot0),
    .master_op0    (i_master0),
    .mastlock_op0  (i_mastlock0),
    .wdata_op0     (HWDATACPU),
    .wuser_op0     (HWUSERCPU),
    .held_tran_op0  (i_held_tran0),

    // Slave read data and response
    .HREADYOUTM (HREADYOUT_GRAPHIC_RAM),

    .active_op0    (i_active0to1),

    // Slave Address/Control Signals
    .HSELM      (HSEL_GRAPHIC_RAM),
    .HADDRM     (HADDR_GRAPHIC_RAM),
    .HAUSERM    (HAUSER_GRAPHIC_RAM),
    .HTRANSM    (HTRANS_GRAPHIC_RAM),
    .HWRITEM    (HWRITE_GRAPHIC_RAM),
    .HSIZEM     (HSIZE_GRAPHIC_RAM),
    .HBURSTM    (HBURST_GRAPHIC_RAM),
    .HPROTM     (HPROT_GRAPHIC_RAM),
    .HMASTERM   (HMASTER_GRAPHIC_RAM),
    .HMASTLOCKM (HMASTLOCK_GRAPHIC_RAM),
    .HREADYMUXM (i_hready_mux__graphic_ram),
    .HWUSERM    (HWUSER_GRAPHIC_RAM),
    .HWDATAM    (HWDATA_GRAPHIC_RAM)

    );

  // Drive output with internal version
  assign HREADYMUX_GRAPHIC_RAM = i_hready_mux__graphic_ram;


  // Output stage for MI2
  Output_Stage_APB u_output_stage_apb_2 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Port 0 Signals
    .sel_op0       (i_sel0to2),
    .addr_op0      (i_addr0),
    .auser_op0     (i_auser0),
    .trans_op0     (i_trans0),
    .write_op0     (i_write0),
    .size_op0      (i_size0),
    .burst_op0     (i_burst0),
    .prot_op0      (i_prot0),
    .master_op0    (i_master0),
    .mastlock_op0  (i_mastlock0),
    .wdata_op0     (HWDATACPU),
    .wuser_op0     (HWUSERCPU),
    .held_tran_op0  (i_held_tran0),

    // Slave read data and response
    .HREADYOUTM (HREADYOUT_APB),

    .active_op0    (i_active0to2),

    // Slave Address/Control Signals
    .HSELM      (HSEL_APB),
    .HADDRM     (HADDR_APB),
    .HAUSERM    (HAUSER_APB),
    .HTRANSM    (HTRANS_APB),
    .HWRITEM    (HWRITE_APB),
    .HSIZEM     (HSIZE_APB),
    .HBURSTM    (HBURST_APB),
    .HPROTM     (HPROT_APB),
    .HMASTERM   (HMASTER_APB),
    .HMASTLOCKM (HMASTLOCK_APB),
    .HREADYMUXM (i_hready_mux__apb),
    .HWUSERM    (HWUSER_APB),
    .HWDATAM    (HWDATA_APB)

    );

  // Drive output with internal version
  assign HREADYMUX_APB = i_hready_mux__apb;


  // Output stage for MI3
  Output_Stage_NES_RAM u_output_stage_nes_ram_3 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Port 0 Signals
    .sel_op0       (i_sel0to3),
    .addr_op0      (i_addr0),
    .auser_op0     (i_auser0),
    .trans_op0     (i_trans0),
    .write_op0     (i_write0),
    .size_op0      (i_size0),
    .burst_op0     (i_burst0),
    .prot_op0      (i_prot0),
    .master_op0    (i_master0),
    .mastlock_op0  (i_mastlock0),
    .wdata_op0     (HWDATACPU),
    .wuser_op0     (HWUSERCPU),
    .held_tran_op0  (i_held_tran0),

    // Port 1 Signals
    .sel_op1       (i_sel1to3),
    .addr_op1      (i_addr1),
    .auser_op1     (i_auser1),
    .trans_op1     (i_trans1),
    .write_op1     (i_write1),
    .size_op1      (i_size1),
    .burst_op1     (i_burst1),
    .prot_op1      (i_prot1),
    .master_op1    (i_master1),
    .mastlock_op1  (i_mastlock1),
    .wdata_op1     (HWDATANES),
    .wuser_op1     (HWUSERNES),
    .held_tran_op1  (i_held_tran1),

    // Slave read data and response
    .HREADYOUTM (HREADYOUT_NES_RAM),

    .active_op0    (i_active0to3),
    .active_op1    (i_active1to3),

    // Slave Address/Control Signals
    .HSELM      (HSEL_NES_RAM),
    .HADDRM     (HADDR_NES_RAM),
    .HAUSERM    (HAUSER_NES_RAM),
    .HTRANSM    (HTRANS_NES_RAM),
    .HWRITEM    (HWRITE_NES_RAM),
    .HSIZEM     (HSIZE_NES_RAM),
    .HBURSTM    (HBURST_NES_RAM),
    .HPROTM     (HPROT_NES_RAM),
    .HMASTERM   (HMASTER_NES_RAM),
    .HMASTLOCKM (HMASTLOCK_NES_RAM),
    .HREADYMUXM (i_hready_mux__nes_ram),
    .HWUSERM    (HWUSER_NES_RAM),
    .HWDATAM    (HWDATA_NES_RAM)

    );

  // Drive output with internal version
  assign HREADYMUX_NES_RAM = i_hready_mux__nes_ram;


  // Output stage for MI4
  Output_Stage_SDCARD u_output_stage_sdcard_4 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Port 0 Signals
    .sel_op0       (i_sel0to4),
    .addr_op0      (i_addr0),
    .auser_op0     (i_auser0),
    .trans_op0     (i_trans0),
    .write_op0     (i_write0),
    .size_op0      (i_size0),
    .burst_op0     (i_burst0),
    .prot_op0      (i_prot0),
    .master_op0    (i_master0),
    .mastlock_op0  (i_mastlock0),
    .wdata_op0     (HWDATACPU),
    .wuser_op0     (HWUSERCPU),
    .held_tran_op0  (i_held_tran0),

    // Slave read data and response
    .HREADYOUTM (HREADYOUT_SDCARD),

    .active_op0    (i_active0to4),

    // Slave Address/Control Signals
    .HSELM      (HSEL_SDCARD),
    .HADDRM     (HADDR_SDCARD),
    .HAUSERM    (HAUSER_SDCARD),
    .HTRANSM    (HTRANS_SDCARD),
    .HWRITEM    (HWRITE_SDCARD),
    .HSIZEM     (HSIZE_SDCARD),
    .HBURSTM    (HBURST_SDCARD),
    .HPROTM     (HPROT_SDCARD),
    .HMASTERM   (HMASTER_SDCARD),
    .HMASTLOCKM (HMASTLOCK_SDCARD),
    .HREADYMUXM (i_hready_mux__sdcard),
    .HWUSERM    (HWUSER_SDCARD),
    .HWDATAM    (HWDATA_SDCARD)

    );

  // Drive output with internal version
  assign HREADYMUX_SDCARD = i_hready_mux__sdcard;


  // Output stage for MI5
  Output_Stage_ETHERNET u_output_stage_ethernet_5 (

    // Common AHB signals
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),

    // Port 0 Signals
    .sel_op0       (i_sel0to5),
    .addr_op0      (i_addr0),
    .auser_op0     (i_auser0),
    .trans_op0     (i_trans0),
    .write_op0     (i_write0),
    .size_op0      (i_size0),
    .burst_op0     (i_burst0),
    .prot_op0      (i_prot0),
    .master_op0    (i_master0),
    .mastlock_op0  (i_mastlock0),
    .wdata_op0     (HWDATACPU),
    .wuser_op0     (HWUSERCPU),
    .held_tran_op0  (i_held_tran0),

    // Slave read data and response
    .HREADYOUTM (HREADYOUT_ETHERNET),

    .active_op0    (i_active0to5),

    // Slave Address/Control Signals
    .HSELM      (HSEL_ETHERNET),
    .HADDRM     (HADDR_ETHERNET),
    .HAUSERM    (HAUSER_ETHERNET),
    .HTRANSM    (HTRANS_ETHERNET),
    .HWRITEM    (HWRITE_ETHERNET),
    .HSIZEM     (HSIZE_ETHERNET),
    .HBURSTM    (HBURST_ETHERNET),
    .HPROTM     (HPROT_ETHERNET),
    .HMASTERM   (HMASTER_ETHERNET),
    .HMASTLOCKM (HMASTLOCK_ETHERNET),
    .HREADYMUXM (i_hready_mux__ethernet),
    .HWUSERM    (HWUSER_ETHERNET),
    .HWDATAM    (HWDATA_ETHERNET)

    );

  // Drive output with internal version
  assign HREADYMUX_ETHERNET = i_hready_mux__ethernet;


endmodule

// --================================= End ===================================--
