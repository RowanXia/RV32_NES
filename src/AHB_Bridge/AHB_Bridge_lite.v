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
//  Abstract            : BusMatrixLite is a wrapper module that wraps around
//                        the BusMatrix module to give AHB Lite compliant
//                        slave and master interfaces.
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module AHB_Bridge_lite (

    // Common AHB signals
    HCLK,
    HRESETn,

    // System Address Remap control
    REMAP,

    // Input port SI0 (inputs from master 0)
    HADDRCPU,
    HTRANSCPU,
    HWRITECPU,
    HSIZECPU,
    HBURSTCPU,
    HPROTCPU,
    HWDATACPU,
    HMASTLOCKCPU,
    HAUSERCPU,
    HWUSERCPU,

    // Input port SI1 (inputs from master 1)
    HADDRNES,
    HTRANSNES,
    HWRITENES,
    HSIZENES,
    HBURSTNES,
    HPROTNES,
    HWDATANES,
    HMASTLOCKNES,
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
    HWDATA_ETHERNET,
    HMASTLOCK_ETHERNET,
    HREADYMUX_ETHERNET,
    HAUSER_ETHERNET,
    HWUSER_ETHERNET,

    // Input port SI0 (outputs to master 0)
    HRDATACPU,
    HREADYCPU,
    HRESPCPU,
    HRUSERCPU,

    // Input port SI1 (outputs to master 1)
    HRDATANES,
    HREADYNES,
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

    // System Address Remap control
    input   [3:0] REMAP;           // System Address REMAP control

    // Input port SI0 (inputs from master 0)
    input  [31:0] HADDRCPU;         // Address bus
    input   [1:0] HTRANSCPU;        // Transfer type
    input         HWRITECPU;        // Transfer direction
    input   [2:0] HSIZECPU;         // Transfer size
    input   [2:0] HBURSTCPU;        // Burst type
    input   [3:0] HPROTCPU;         // Protection control
    input  [31:0] HWDATACPU;        // Write data
    input         HMASTLOCKCPU;     // Locked Sequence
    input  [31:0] HAUSERCPU;        // Address USER signals
    input  [31:0] HWUSERCPU;        // Write-data USER signals

    // Input port SI1 (inputs from master 1)
    input  [31:0] HADDRNES;         // Address bus
    input   [1:0] HTRANSNES;        // Transfer type
    input         HWRITENES;        // Transfer direction
    input   [2:0] HSIZENES;         // Transfer size
    input   [2:0] HBURSTNES;        // Burst type
    input   [3:0] HPROTNES;         // Protection control
    input  [31:0] HWDATANES;        // Write data
    input         HMASTLOCKNES;     // Locked Sequence
    input  [31:0] HAUSERNES;        // Address USER signals
    input  [31:0] HWUSERNES;        // Write-data USER signals

    // Output port MI0 (inputs from slave 0)
    input  [31:0] HRDATA_PRG_RAM;        // Read data bus
    input         HREADYOUT_PRG_RAM;     // HREADY feedback
    input         HRESP_PRG_RAM;         // Transfer response
    input  [31:0] HRUSER_PRG_RAM;        // Read-data USER signals

    // Output port MI1 (inputs from slave 1)
    input  [31:0] HRDATA_GRAPHIC_RAM;        // Read data bus
    input         HREADYOUT_GRAPHIC_RAM;     // HREADY feedback
    input         HRESP_GRAPHIC_RAM;         // Transfer response
    input  [31:0] HRUSER_GRAPHIC_RAM;        // Read-data USER signals

    // Output port MI2 (inputs from slave 2)
    input  [31:0] HRDATA_APB;        // Read data bus
    input         HREADYOUT_APB;     // HREADY feedback
    input         HRESP_APB;         // Transfer response
    input  [31:0] HRUSER_APB;        // Read-data USER signals

    // Output port MI3 (inputs from slave 3)
    input  [31:0] HRDATA_NES_RAM;        // Read data bus
    input         HREADYOUT_NES_RAM;     // HREADY feedback
    input         HRESP_NES_RAM;         // Transfer response
    input  [31:0] HRUSER_NES_RAM;        // Read-data USER signals

    // Output port MI4 (inputs from slave 4)
    input  [31:0] HRDATA_SDCARD;        // Read data bus
    input         HREADYOUT_SDCARD;     // HREADY feedback
    input         HRESP_SDCARD;         // Transfer response
    input  [31:0] HRUSER_SDCARD;        // Read-data USER signals

    // Output port MI5 (inputs from slave 5)
    input  [31:0] HRDATA_ETHERNET;        // Read data bus
    input         HREADYOUT_ETHERNET;     // HREADY feedback
    input         HRESP_ETHERNET;         // Transfer response
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
    output [31:0] HWDATA_ETHERNET;        // Write data
    output        HMASTLOCK_ETHERNET;     // Locked Sequence
    output        HREADYMUX_ETHERNET;     // Transfer done
    output [31:0] HAUSER_ETHERNET;        // Address USER signals
    output [31:0] HWUSER_ETHERNET;        // Write-data USER signals

    // Input port SI0 (outputs to master 0)
    output [31:0] HRDATACPU;        // Read data bus
    output        HREADYCPU;     // HREADY feedback
    output        HRESPCPU;         // Transfer response
    output [31:0] HRUSERCPU;        // Read-data USER signals

    // Input port SI1 (outputs to master 1)
    output [31:0] HRDATANES;        // Read data bus
    output        HREADYNES;     // HREADY feedback
    output        HRESPNES;         // Transfer response
    output [31:0] HRUSERNES;        // Read-data USER signals

    // Scan test dummy signals; not connected until scan insertion
    output        SCANOUTHCLK;     // Scan Chain Output

// -----------------------------------------------------------------------------
// Wire declarations
// -----------------------------------------------------------------------------

    // Common AHB signals
    wire         HCLK;            // AHB System Clock
    wire         HRESETn;         // AHB System Reset

    // System Address Remap control
    wire   [3:0] REMAP;           // System REMAP signal

    // Input Port SI0
    wire  [31:0] HADDRCPU;         // Address bus
    wire   [1:0] HTRANSCPU;        // Transfer type
    wire         HWRITECPU;        // Transfer direction
    wire   [2:0] HSIZECPU;         // Transfer size
    wire   [2:0] HBURSTCPU;        // Burst type
    wire   [3:0] HPROTCPU;         // Protection control
    wire  [31:0] HWDATACPU;        // Write data
    wire         HMASTLOCKCPU;     // Locked Sequence

    wire  [31:0] HRDATACPU;        // Read data bus
    wire         HREADYCPU;     // HREADY feedback
    wire         HRESPCPU;         // Transfer response
    wire  [31:0] HAUSERCPU;        // Address USER signals
    wire  [31:0] HWUSERCPU;        // Write-data USER signals
    wire  [31:0] HRUSERCPU;        // Read-data USER signals

    // Input Port SI1
    wire  [31:0] HADDRNES;         // Address bus
    wire   [1:0] HTRANSNES;        // Transfer type
    wire         HWRITENES;        // Transfer direction
    wire   [2:0] HSIZENES;         // Transfer size
    wire   [2:0] HBURSTNES;        // Burst type
    wire   [3:0] HPROTNES;         // Protection control
    wire  [31:0] HWDATANES;        // Write data
    wire         HMASTLOCKNES;     // Locked Sequence

    wire  [31:0] HRDATANES;        // Read data bus
    wire         HREADYNES;     // HREADY feedback
    wire         HRESPNES;         // Transfer response
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
    wire  [31:0] HWDATA_PRG_RAM;        // Write data
    wire         HMASTLOCK_PRG_RAM;     // Locked Sequence
    wire         HREADYMUX_PRG_RAM;     // Transfer done

    wire  [31:0] HRDATA_PRG_RAM;        // Read data bus
    wire         HREADYOUT_PRG_RAM;     // HREADY feedback
    wire         HRESP_PRG_RAM;         // Transfer response
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
    wire  [31:0] HWDATA_GRAPHIC_RAM;        // Write data
    wire         HMASTLOCK_GRAPHIC_RAM;     // Locked Sequence
    wire         HREADYMUX_GRAPHIC_RAM;     // Transfer done

    wire  [31:0] HRDATA_GRAPHIC_RAM;        // Read data bus
    wire         HREADYOUT_GRAPHIC_RAM;     // HREADY feedback
    wire         HRESP_GRAPHIC_RAM;         // Transfer response
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
    wire  [31:0] HWDATA_APB;        // Write data
    wire         HMASTLOCK_APB;     // Locked Sequence
    wire         HREADYMUX_APB;     // Transfer done

    wire  [31:0] HRDATA_APB;        // Read data bus
    wire         HREADYOUT_APB;     // HREADY feedback
    wire         HRESP_APB;         // Transfer response
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
    wire  [31:0] HWDATA_NES_RAM;        // Write data
    wire         HMASTLOCK_NES_RAM;     // Locked Sequence
    wire         HREADYMUX_NES_RAM;     // Transfer done

    wire  [31:0] HRDATA_NES_RAM;        // Read data bus
    wire         HREADYOUT_NES_RAM;     // HREADY feedback
    wire         HRESP_NES_RAM;         // Transfer response
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
    wire  [31:0] HWDATA_SDCARD;        // Write data
    wire         HMASTLOCK_SDCARD;     // Locked Sequence
    wire         HREADYMUX_SDCARD;     // Transfer done

    wire  [31:0] HRDATA_SDCARD;        // Read data bus
    wire         HREADYOUT_SDCARD;     // HREADY feedback
    wire         HRESP_SDCARD;         // Transfer response
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
    wire  [31:0] HWDATA_ETHERNET;        // Write data
    wire         HMASTLOCK_ETHERNET;     // Locked Sequence
    wire         HREADYMUX_ETHERNET;     // Transfer done

    wire  [31:0] HRDATA_ETHERNET;        // Read data bus
    wire         HREADYOUT_ETHERNET;     // HREADY feedback
    wire         HRESP_ETHERNET;         // Transfer response
    wire  [31:0] HAUSER_ETHERNET;        // Address USER signals
    wire  [31:0] HWUSER_ETHERNET;        // Write-data USER signals
    wire  [31:0] HRUSER_ETHERNET;        // Read-data USER signals


// -----------------------------------------------------------------------------
// Signal declarations
// -----------------------------------------------------------------------------
    wire   [3:0] tie_hi_4;
    wire         tie_hi;
    wire         tie_low;
    wire   [1:0] i_hrespCPU;
    wire   [1:0] i_hrespNES;

    wire   [3:0]        i_hmaster_PRG_RAM;
    wire   [1:0] i_hresp_PRG_RAM;
    wire   [3:0]        i_hmaster_GRAPHIC_RAM;
    wire   [1:0] i_hresp_GRAPHIC_RAM;
    wire   [3:0]        i_hmaster_APB;
    wire   [1:0] i_hresp_APB;
    wire   [3:0]        i_hmaster_NES_RAM;
    wire   [1:0] i_hresp_NES_RAM;
    wire   [3:0]        i_hmaster_SDCARD;
    wire   [1:0] i_hresp_SDCARD;
    wire   [3:0]        i_hmaster_ETHERNET;
    wire   [1:0] i_hresp_ETHERNET;

// -----------------------------------------------------------------------------
// Beginning of main code
// -----------------------------------------------------------------------------

    assign tie_hi   = 1'b1;
    assign tie_hi_4 = 4'b1111;
    assign tie_low  = 1'b0;


    assign HRESPCPU  = i_hrespCPU[0];

    assign HRESPNES  = i_hrespNES[0];

    assign i_hresp_PRG_RAM = {tie_low, HRESP_PRG_RAM};
    assign i_hresp_GRAPHIC_RAM = {tie_low, HRESP_GRAPHIC_RAM};
    assign i_hresp_APB = {tie_low, HRESP_APB};
    assign i_hresp_NES_RAM = {tie_low, HRESP_NES_RAM};
    assign i_hresp_SDCARD = {tie_low, HRESP_SDCARD};
    assign i_hresp_ETHERNET = {tie_low, HRESP_ETHERNET};

// BusMatrix instance
  AHB_Bridge uAHB_Bridge (
    .HCLK       (HCLK),
    .HRESETn    (HRESETn),
    .REMAP      (REMAP),

    // Input port SI0 signals
    .HSELCPU       (tie_hi),
    .HADDRCPU      (HADDRCPU),
    .HTRANSCPU     (HTRANSCPU),
    .HWRITECPU     (HWRITECPU),
    .HSIZECPU      (HSIZECPU),
    .HBURSTCPU     (HBURSTCPU),
    .HPROTCPU      (HPROTCPU),
    .HWDATACPU     (HWDATACPU),
    .HMASTLOCKCPU  (HMASTLOCKCPU),
    .HMASTERCPU    (tie_hi_4),
    .HREADYCPU     (HREADYCPU),
    .HAUSERCPU     (HAUSERCPU),
    .HWUSERCPU     (HWUSERCPU),
    .HRDATACPU     (HRDATACPU),
    .HREADYOUTCPU  (HREADYCPU),
    .HRESPCPU      (i_hrespCPU),
    .HRUSERCPU     (HRUSERCPU),

    // Input port SI1 signals
    .HSELNES       (tie_hi),
    .HADDRNES      (HADDRNES),
    .HTRANSNES     (HTRANSNES),
    .HWRITENES     (HWRITENES),
    .HSIZENES      (HSIZENES),
    .HBURSTNES     (HBURSTNES),
    .HPROTNES      (HPROTNES),
    .HWDATANES     (HWDATANES),
    .HMASTLOCKNES  (HMASTLOCKNES),
    .HMASTERNES    (tie_hi_4),
    .HREADYNES     (HREADYNES),
    .HAUSERNES     (HAUSERNES),
    .HWUSERNES     (HWUSERNES),
    .HRDATANES     (HRDATANES),
    .HREADYOUTNES  (HREADYNES),
    .HRESPNES      (i_hrespNES),
    .HRUSERNES     (HRUSERNES),


    // Output port MI0 signals
    .HSEL_PRG_RAM       (HSEL_PRG_RAM),
    .HADDR_PRG_RAM      (HADDR_PRG_RAM),
    .HTRANS_PRG_RAM     (HTRANS_PRG_RAM),
    .HWRITE_PRG_RAM     (HWRITE_PRG_RAM),
    .HSIZE_PRG_RAM      (HSIZE_PRG_RAM),
    .HBURST_PRG_RAM     (HBURST_PRG_RAM),
    .HPROT_PRG_RAM      (HPROT_PRG_RAM),
    .HWDATA_PRG_RAM     (HWDATA_PRG_RAM),
    .HMASTER_PRG_RAM    (i_hmaster_PRG_RAM),
    .HMASTLOCK_PRG_RAM  (HMASTLOCK_PRG_RAM),
    .HREADYMUX_PRG_RAM  (HREADYMUX_PRG_RAM),
    .HAUSER_PRG_RAM     (HAUSER_PRG_RAM),
    .HWUSER_PRG_RAM     (HWUSER_PRG_RAM),
    .HRDATA_PRG_RAM     (HRDATA_PRG_RAM),
    .HREADYOUT_PRG_RAM  (HREADYOUT_PRG_RAM),
    .HRESP_PRG_RAM      (i_hresp_PRG_RAM),
    .HRUSER_PRG_RAM     (HRUSER_PRG_RAM),

    // Output port MI1 signals
    .HSEL_GRAPHIC_RAM       (HSEL_GRAPHIC_RAM),
    .HADDR_GRAPHIC_RAM      (HADDR_GRAPHIC_RAM),
    .HTRANS_GRAPHIC_RAM     (HTRANS_GRAPHIC_RAM),
    .HWRITE_GRAPHIC_RAM     (HWRITE_GRAPHIC_RAM),
    .HSIZE_GRAPHIC_RAM      (HSIZE_GRAPHIC_RAM),
    .HBURST_GRAPHIC_RAM     (HBURST_GRAPHIC_RAM),
    .HPROT_GRAPHIC_RAM      (HPROT_GRAPHIC_RAM),
    .HWDATA_GRAPHIC_RAM     (HWDATA_GRAPHIC_RAM),
    .HMASTER_GRAPHIC_RAM    (i_hmaster_GRAPHIC_RAM),
    .HMASTLOCK_GRAPHIC_RAM  (HMASTLOCK_GRAPHIC_RAM),
    .HREADYMUX_GRAPHIC_RAM  (HREADYMUX_GRAPHIC_RAM),
    .HAUSER_GRAPHIC_RAM     (HAUSER_GRAPHIC_RAM),
    .HWUSER_GRAPHIC_RAM     (HWUSER_GRAPHIC_RAM),
    .HRDATA_GRAPHIC_RAM     (HRDATA_GRAPHIC_RAM),
    .HREADYOUT_GRAPHIC_RAM  (HREADYOUT_GRAPHIC_RAM),
    .HRESP_GRAPHIC_RAM      (i_hresp_GRAPHIC_RAM),
    .HRUSER_GRAPHIC_RAM     (HRUSER_GRAPHIC_RAM),

    // Output port MI2 signals
    .HSEL_APB       (HSEL_APB),
    .HADDR_APB      (HADDR_APB),
    .HTRANS_APB     (HTRANS_APB),
    .HWRITE_APB     (HWRITE_APB),
    .HSIZE_APB      (HSIZE_APB),
    .HBURST_APB     (HBURST_APB),
    .HPROT_APB      (HPROT_APB),
    .HWDATA_APB     (HWDATA_APB),
    .HMASTER_APB    (i_hmaster_APB),
    .HMASTLOCK_APB  (HMASTLOCK_APB),
    .HREADYMUX_APB  (HREADYMUX_APB),
    .HAUSER_APB     (HAUSER_APB),
    .HWUSER_APB     (HWUSER_APB),
    .HRDATA_APB     (HRDATA_APB),
    .HREADYOUT_APB  (HREADYOUT_APB),
    .HRESP_APB      (i_hresp_APB),
    .HRUSER_APB     (HRUSER_APB),

    // Output port MI3 signals
    .HSEL_NES_RAM       (HSEL_NES_RAM),
    .HADDR_NES_RAM      (HADDR_NES_RAM),
    .HTRANS_NES_RAM     (HTRANS_NES_RAM),
    .HWRITE_NES_RAM     (HWRITE_NES_RAM),
    .HSIZE_NES_RAM      (HSIZE_NES_RAM),
    .HBURST_NES_RAM     (HBURST_NES_RAM),
    .HPROT_NES_RAM      (HPROT_NES_RAM),
    .HWDATA_NES_RAM     (HWDATA_NES_RAM),
    .HMASTER_NES_RAM    (i_hmaster_NES_RAM),
    .HMASTLOCK_NES_RAM  (HMASTLOCK_NES_RAM),
    .HREADYMUX_NES_RAM  (HREADYMUX_NES_RAM),
    .HAUSER_NES_RAM     (HAUSER_NES_RAM),
    .HWUSER_NES_RAM     (HWUSER_NES_RAM),
    .HRDATA_NES_RAM     (HRDATA_NES_RAM),
    .HREADYOUT_NES_RAM  (HREADYOUT_NES_RAM),
    .HRESP_NES_RAM      (i_hresp_NES_RAM),
    .HRUSER_NES_RAM     (HRUSER_NES_RAM),

    // Output port MI4 signals
    .HSEL_SDCARD       (HSEL_SDCARD),
    .HADDR_SDCARD      (HADDR_SDCARD),
    .HTRANS_SDCARD     (HTRANS_SDCARD),
    .HWRITE_SDCARD     (HWRITE_SDCARD),
    .HSIZE_SDCARD      (HSIZE_SDCARD),
    .HBURST_SDCARD     (HBURST_SDCARD),
    .HPROT_SDCARD      (HPROT_SDCARD),
    .HWDATA_SDCARD     (HWDATA_SDCARD),
    .HMASTER_SDCARD    (i_hmaster_SDCARD),
    .HMASTLOCK_SDCARD  (HMASTLOCK_SDCARD),
    .HREADYMUX_SDCARD  (HREADYMUX_SDCARD),
    .HAUSER_SDCARD     (HAUSER_SDCARD),
    .HWUSER_SDCARD     (HWUSER_SDCARD),
    .HRDATA_SDCARD     (HRDATA_SDCARD),
    .HREADYOUT_SDCARD  (HREADYOUT_SDCARD),
    .HRESP_SDCARD      (i_hresp_SDCARD),
    .HRUSER_SDCARD     (HRUSER_SDCARD),

    // Output port MI5 signals
    .HSEL_ETHERNET       (HSEL_ETHERNET),
    .HADDR_ETHERNET      (HADDR_ETHERNET),
    .HTRANS_ETHERNET     (HTRANS_ETHERNET),
    .HWRITE_ETHERNET     (HWRITE_ETHERNET),
    .HSIZE_ETHERNET      (HSIZE_ETHERNET),
    .HBURST_ETHERNET     (HBURST_ETHERNET),
    .HPROT_ETHERNET      (HPROT_ETHERNET),
    .HWDATA_ETHERNET     (HWDATA_ETHERNET),
    .HMASTER_ETHERNET    (i_hmaster_ETHERNET),
    .HMASTLOCK_ETHERNET  (HMASTLOCK_ETHERNET),
    .HREADYMUX_ETHERNET  (HREADYMUX_ETHERNET),
    .HAUSER_ETHERNET     (HAUSER_ETHERNET),
    .HWUSER_ETHERNET     (HWUSER_ETHERNET),
    .HRDATA_ETHERNET     (HRDATA_ETHERNET),
    .HREADYOUT_ETHERNET  (HREADYOUT_ETHERNET),
    .HRESP_ETHERNET      (i_hresp_ETHERNET),
    .HRUSER_ETHERNET     (HRUSER_ETHERNET),


    // Scan test dummy signals; not connected until scan insertion
    .SCANENABLE            (SCANENABLE),
    .SCANINHCLK            (SCANINHCLK),
    .SCANOUTHCLK           (SCANOUTHCLK)
  );


endmodule
