/******************************************************************************
* Copyright (c) 2014 - 2021 Xilinx, Inc.  All rights reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*****************************************************************************/
/**
* @file boot.S
*
* @addtogroup a53_64_boot_code Cortex A53 64bit Processor Boot Code
* @{
* <h2> boot.S </h2>
*
* The boot code performs minimum configuration which is required for an
* application. Cortex-A53 starts by checking current exception level. If the
* current exception level is EL3 and BSP is built for EL3, it will do
* initialization required for application execution at EL3. Below is a
* sequence illustrating what all configuration is performed before control
* reaches to main function for EL3 execution.
*
* 1. Program vector table base for exception handling
* 2. Set reset vector table base address
* 3. Program stack pointer for EL3
* 4. Routing of interrupts to EL3
* 5. Enable ECC protection
* 6. Program generic counter frequency
* 7. Invalidate instruction cache, data cache and TLBs
* 8. Configure MMU registers and program base address of translation table
* 9. Transfer control to _start which clears BSS sections and runs global
*    constructor before jumping to main application
*
* If the current exception level is EL1 and BSP is also built for EL1_NONSECURE
* it will perform initialization required for application execution at EL1
* non-secure. For all other combination, the execution will go into infinite
* loop. Below is a sequence illustrating what all configuration is performed
* before control reaches to main function for EL1 execution.
*
* 1. Program vector table base for exception handling
* 2. Program stack pointer for EL1
* 3. Invalidate instruction cache, data cache and TLBs
* 4. Configure MMU registers and program base address of translation table
* 5. Transfer control to _start which clears BSS sections and runs global
*    constructor before jumping to main application
*
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who     Date     Changes
* ----- ------- -------- ---------------------------------------------------
* 5.00  pkp	05/21/14 Initial version
* 6.00	pkp	07/25/16 Program the counter frequency
* 6.02  pkp	01/22/17 Added support for EL1 non-secure
* 6.02	pkp	01/24/17 Clearing status of FPUStatus variable to ensure it
*			 holds correct value.
* 6.3   mus 04/20/17 CPU Cache protection bit in the L2CTLR_EL1 will be in
*			  set state on reset. So, setting that bit through boot
*			  code is redundant, hence removed the code which sets
*			  CPU cache protection bit.
* 6.4   mus	08/11/17 Implemented ARM erratum 855873.It fixes
*				 CR#982209.
* 6.6   mus	01/19/18 Added isb after writing to the cpacr_el1/cptr_el3,
*				 to ensure floating-point unit is disabled, before
*				 any subsequent instruction.
* 7.0   mus	03/26/18 Updated TCR_EL3/TCR_EL1 as per versal address map
* 7.3   mus	04/24/20 Corrected CPACR_EL1 handling at EL1 NS
*
* </pre>
*
******************************************************************************/

#include "xparameters.h"
#include "bspconfig.h"
#include "xil_errata.h"

/* Temporary macro that should be moved out to BSP configuration.
 * Enables initialization of a CPU so that software can use EL3, El1 and EL0 exception levels.

 * EL2 is configured in a minimal way just to enable lower exception levels.
 * At the moment there is no plan for support virtualization.
 */
#define CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT 1

.globl MMUTableL0
.globl MMUTableL1
.globl MMUTableL2
.global _prestart
.global _boot

.global __el3_stack
.global __el2_stack
.global __el1_stack
.global __el0_stack
.global _vector_table
.global _reset_vector

.set EL3_stack, __el3_stack
.set EL2_stack, __el2_stack
.set EL1_stack, __el1_stack
.set EL0_stack, __el0_stack

.set TT_S1_FAULT, 0x0
.set TT_S1_TABLE, 0x3

.set L0Table, MMUTableL0
.set L1Table, MMUTableL1
.set L2Table, MMUTableL2
.set vector_base, _vector_table
.set rvbar_base, 0xFD5C0040
.set reset_vector, _reset_vector

#if defined (versal)
.set counterfreq, XPAR_CPU_CORTEXA72_0_TIMESTAMP_CLK_FREQ
#else
.set counterfreq, XPAR_CPU_CORTEXA53_0_TIMESTAMP_CLK_FREQ
#endif

.set MODE_EL1, 0x5
.set DAIF_BIT, 0x1C0

.section .boot,"ax"


/* this initializes the various processor modes */

_prestart:
_boot:
	mov	x0, #0
	mov	x1, #0
	mov	x2, #0
	mov	x3, #0
	mov	x4, #0
	mov	x5, #0
	mov	x6, #0
	mov	x7, #0
	mov	x8, #0
	mov	x9, #0
	mov	x10, #0
	mov	x11, #0
	mov	x12, #0
	mov	x13, #0
	mov	x14, #0
	mov	x15, #0
	mov	x16, #0
	mov	x17, #0
	mov	x18, #0
	mov	x19, #0
	mov	x20, #0
	mov	x21, #0
	mov	x22, #0
	mov	x23, #0
	mov	x24, #0
	mov	x25, #0
	mov	x26, #0
	mov	x27, #0
	mov	x28, #0
	mov	x29, #0
	mov	x30, #0
#if 0 //don't put other a53 cpus in wfi
	/* Which core am I ? */
	mrs	x0, MPIDR_EL1
	and	x0, x0, #0xFF	// Mask off to leave Aff0
	cbz	x0, OKToRun	// If core 0, run the primary init code
EndlessLoop0:
	wfi
	b	EndlessLoop0
#endif
OKToRun:

	mrs	x0, currentEL
	cmp	x0, #0xC
	beq	InitEL3

	cmp	x0, #0x4
	beq	InitEL1

	b 	error		// go to error if current exception level is neither EL3 nor EL1
InitEL3:
#ifndef CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT
.if (EL3 == 1)
#endif /* CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT */
	/* Set vector table base address*/
	ldr	x1, =vector_base
	msr	VBAR_EL3, x1

	/* Set reset vector address */
	ldr	x1, =reset_vector
	/* Get the cpu ID */
	mrs	x0, MPIDR_EL1
	and	x0, x0, #0xFF
	mov	w0, w0
	ldr	w2, =rvbar_base
	/* Calculate the rvbar base address for particular CPU core */
	mov	w3, #0x8
	mul	w0, w0, w3
	add	w2, w2, w0
	/* Store vector base address to RVBAR */
	str	x1, [x2]

	/* Define stack pointer for current exception level*/
	ldr	x2, =EL3_stack
	mov	sp, x2

	/* All architectural features are not traped to EL3 */
	mov	x0, #0
	msr	CPTR_EL3, x0
	isb

	/* Clear FPUStatus variable to make sure that it contains current
	 * status of FPU i.e. disabled. In case of a warm restart execution
	 * when bss sections are not cleared, it may contain previously updated
	 * value which does not hold true now.
	 */
#ifndef FREERTOS_BSP
	 ldr	x0, =FPUStatus
	 str 	xzr, [x0]
#endif

	/* Configure SCR_EL3 (following Arm Cortex - A53 MPCore Processor TRM Revision: r0p4):
	 * - Do not trap WFE (TWE bit[13] = 0) WFI (TWI - bit[12] = 0) to EL3
	 * - Enable Secure EL1 access to CNTPS_TVAL_EL1, CNTS_CTL_EL1, and CNTPS_CVAL_EL1 registers
	 *   (ST bit[11] = 1)
	 * - Enable AArch64 for EL2, EL1 and EL0 (RW bit[10] = 1)
	 * - Allow to fetch instustions from non-secure memory while being in secure mode
	 *   (SIF bit[9] = 0)
	 * - HVC Hyp call is disabled (HCE bit[8] = 0) for all exceptions levels.
	 *   There is no plan to implement virtualization.
	 * - Enable SMC instructions for all exception levels (SMD bit[7] - 0)
	 * - Route the external aborts and SError to ELx (EA bit[3] - 0)
	 * - Route FIQ to ELx (FIQ bit[2] - 0)
	 * - Route IRQ to ELx (IRQ bit[1] - 0)
	 * - Continue initialization in secure mode (NS bit[0] - 0).
	 *   The EL2 system control registers will be initialized directly from EL3 hence there is
	 *   no need to change to non-secure mode.
	 */
	mov	w1, #0			// Initial value of register is unknown
	orr	w1, w1, #(1 << 11)	// Set ST bit
	orr	w1, w1, #(1 << 10)	// Set RW bit
	msr	SCR_EL3, x1

	/* Configure cpu auxiliary control register EL1:
	 * - Enable 128th consecutive streaming cache line doe not allocate in the L1 or L2 (RADIS
	 *   bits [28:27] = 0b01)
	 * - Enable 2 independend data prefetch streams (NPFSTRM bits [20:19] = 0b01)
	 * - Enable 5 outstanding L1 data prefetches allowed (L1PCTL bits [15:13] = 0b01)
	 */
	mov	x0, #0
	orr	x0, x0, #(0b01 << 27)	// Set RADIS bits
	orr	x0, x0, #(0b01 << 19)	// Set NPFSTRM bits
	orr	x0, x0, #(0b01 << 13)	// Set L1PCTL bits
#if CONFIG_ARM_ERRATA_855873
	/*  Set ENDCCASCI bit in CPUACTLR_EL1 register, to execute data
	 *  cache clean operations as data cache clean and invalidate.
	 */
	orr	x0, x0, #(1 << 44)	// Set ENDCCASCI bit
#endif
	msr	S3_1_C15_C2_0, x0 	// CPUACTLR_EL1

	/* Program the counter frequency. It may be confiugre from highest available exception level
	 * only.
	 */
	ldr	x0,=counterfreq
	msr	CNTFRQ_EL0, x0

	/* Configure CPU Extended Control Register:
	 * - Enable hardware coherency between cores (SMPEN bit[6] = 1)
	 * - Disable SIMD and Floating-point retenction circuit (FPRETCTL bits[5:3] = 0b000).
	 *   This is default value after reset.
	 * - Disable CPU retention circuit (CPURETCTL bits[2:0] = 0b000). This is default value
	 *   after reset.
	 */
	mrs	x0, S3_1_c15_c2_1	// Read EL1 CPU Extended Control Register
	orr	x0, x0, #(1 << 6)	// Set the SMPEN bit
	msr	S3_1_c15_c2_1, x0	// Write EL1 CPU Extended Control Register
	isb

	tlbi	ALLE3
	ic	IALLU			// Invalidate I cache to PoU
	bl	invalidate_dcaches
	dsb	sy
	isb

	ldr	x1, =L0Table		// Get address of level 0 for TTBR0_EL3
	msr	TTBR0_EL3, x1		// Set TTBR0_EL3

	/* Set up memory attributes. This equates to:
	 * 0 = b01000100 = Normal, Inner/Outer Non-Cacheable
	 * 1 = b11111111 = Normal, Inner/Outer WB/WA/RA
	 * 2 = b00000000 = Device-nGnRnE
	 * 3 = b00000100 = Device-nGnRE
	 * 4 = b10111011 = Normal, Inner/Outer WT/WA/RA
	 */
	ldr	x1, =0x000000BB0400FF44
	msr	MAIR_EL3, x1

#if defined (versal)
	/* Set up TCR_EL3:
	 * - Physical Address Size PS =  100 -> 44bits 16 TB
	 * - Granual Size TG0 = 00 -> 4KB
	 * - Size offset of the memory region T0SZ = 20 -> (region size 2^(64-20) = 2^44)
	 */
	ldr	x1,=0x80843514
#else
	/* Set up TCR_EL3:
	 * - Physical Address Size PS =  010 -> 40bits 1TB
	 * - Granual Size TG0 = 00 -> 4KB
	 * - Size offset of the memory region T0SZ = 24 -> (region size 2^(64-24) = 2^40)
	 */
	ldr	x1, =0x80823518
#endif
	msr	TCR_EL3, x1
	isb

#ifndef CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT
	/* Enable SError Exception for asynchronous abort */
	mrs	x1, DAIF
	bic	x1, x1,#(0x1<<8)
	msr	DAIF, x1
#endif /* CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT */

	/* Configure System Control Register SCTLR_EL3:
	 * - Use little endian for data access and stage 1 translation table at EL3 (EE bit[25] = 0)
	 * - Do not force XN permissions for regions with write permissions (WXN bit[19] = 0)
	 * - Enable instructions cache (I bit[12] - 1)
	 * - Enable stack pointer alignment check (SA bit[3] = 1)
	 * - Enable data and unified cache (C bit[2] = 1)
	 * - Disable alignment fault checking (A bit[1] = 0)
	 * - Enable MMU for EL3 (M bit[0] = 1)
	 */
	mov	x1, #0			// Most of the SCTLR_EL3 bits are unknown at reset
	orr	x1, x1, #(1 << 12)	// Set I bit
	orr	x1, x1, #(1 << 3)	// Set SP bit
	orr	x1, x1, #(1 << 2)	// Set C bit
	orr	x1, x1, #(1 << 0)	// Set M bit
	msr	SCTLR_EL3, x1
	dsb	sy
	isb

#ifndef CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT
	b	_startup
#endif /* CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT */

InitEL2:
	/* Configure Exception Level 2 to allow to jump to Exception Level 1. The EL2 will be not
	 * used, hence minimal configuration is required to disable VM related features and trapping
	 * of any instructions or register accesses to EL2.
	 */

	/* Set vector table base address. The EL2 (support for virtualization) is not planned to be
	 * in use.
	 *
	 * ToDo: Change to EL2 specific exceptions vector table with graceful handling of unexpected
	 *       exceptions arriving to EL2.
	 */
	ldr	x1, =vector_base
	msr	VBAR_EL2, x1

	/* Define stack pointer for current exception level*/
	ldr	x2, =EL2_stack
	mov	sp, x2

	/* Set address translation L0 table for EL2.
	 * Virtualization will not be enabled hence the Virtualization Translation Table Base
	 * Address Register (VTTBR_EL2) is not set (left in default, unknonw state).
	 *
	 * ToDo: Check if the table and memory should be configured in the same way for different
	 * exception levels.
	 */
	ldr	x1, =L0Table		// Get address of level 0 for TTBR0_EL3
	msr	TTBR0_EL2, x1		// Set TTBR0_EL3

	/* Set up memory attributes. This equates to:
	 * 0 = b01000100 = Normal, Inner/Outer Non-Cacheable
	 * 1 = b11111111 = Normal, Inner/Outer WB/WA/RA
	 * 2 = b00000000 = Device-nGnRnE
	 * 3 = b00000100 = Device-nGnRE
	 * 4 = b10111011 = Normal, Inner/Outer WT/WA/RA
	 */
	ldr	x1, =0x000000BB0400FF44
	msr	MAIR_EL2, x1

#if defined (versal)
	/* Set up TCR_EL3:
	 * - Physical Address Size PS =  100 -> 44bits 16 TB
	 * - Granual Size TG0 = 00 -> 4KB
	 * - Size offset of the memory region T0SZ = 20 -> (region size 2^(64-20) = 2^44)
	 */
	ldr	x1,=0x80843514
#else
	/* Set up TCR_EL3:
	 * - Physical Address Size PS =  010 -> 40bits 1TB
	 * - Granual Size TG0 = 00 -> 4KB
	 * - Size offset of the memory region T0SZ = 24 -> (region size 2^(64-24) = 2^40)
	 */
	ldr	x1, =0x80823518
#endif
	/* ToDo: Check if configuration of TCR_EL2 should be the same as TCR_EL3 */
	msr	TCR_EL2, x1
	isb
	/* Virtualization will not be enabled hence the Virtualization Translation Control Register
	 * (VTCR_EL2) is not set (left in defaul, unknown state).
	 */

	/* Set Hypervison Configuration Register (HCR_EL2):
	 * - Do not disable stage 2 instcutions cache, reset value (ID bit[33] = 0)
	 * - Do not disable stage 2 data cache, reset value (CD bit[32] = 0)
	 * - Enable AArch64 for EL1 exception level (RW bit[31] = 1). EL0 is configured by EL1
	 *   register
	 * - Do not trap non-secure EL1 reads of the virtual memory control registers to EL2, reset
	 *   value (TRVM bit[30] = 0)
	 * - Do not trap DV ZVA instruction to EL2, reset value (TDZ bit[28] = 0)
	 * - Do not trap general exceptions to EL2 (TGE bit[27] = 0)
	 * - Do not trap non-secure EL1 writes to virtual memory control registers to EL2, reset
	 *   value (TVM bit[26] = 0)
	 * - Do not trap non-secure EL1 TLB maintenance instructions to EL2, reset value (TTLB
	 *   bit[25] = 0)
	 * - Do not trap non-secure EL1, EL0 cache maintenance instructions to Point of Coherency
	 * - to EL2, reset value (TPC bit[24] = 0)
	 * - Do not trap non-secure EL1, EL0 data orunified cache maintenance instructions to Point
	 *   of Coherency (TPC bit[23] = 0)
	 * - Do not trap access to Auxiliary Control Registers to EL2, reset value (TACR bit[21] = 0
	 * - Do not trap non-secure EL1, EL0 access Implenetation Dependent Functionality related
	 *   registers (TIDCP bit[20] = 0)
	 * - Do not trap SMC instruction to EL2, reset value (TSC bit[19] = 0)
	 * - Do not trap non-secure reads of ID group 3 registers to EL2, reset value (TID3
	 *   bit[18] = 0)
	 * - Do not trap non-secure reads of ID group 2 registers to EL2, reset value (TID2
	 *   bit[17] = 0)
	 * - Do not trap non-secure reads of ID group 1 registers to EL2, reset value (TID1
	 *   bit[16] = 0)
	 * - Do not trap non-secure reads of ID group 0 registers to EL2, reset value (TID0
	 *   bit[15] = 0)
	 * - Do not trap non-secure EL1, EL0 WFE instruction to EL2, reset value (TWE bit[14] = 0)
	 * - Do not trap non-secure EL1, EL0 WFI instruction to EL2, reset value (TWI bit[13] = 0)
	 * - Do not enable default cacheability for non-secure EL1, EL0, reset value (DC
	 *   bit[12] = 0)
	 * - Do not upgrade non-secure EL1, EL0 barrier shareability, reset value (BSU
	 *   bits[11:10] = 0b00)
	 * - Do not enable forcing broadcast for Inner Shareable domain when non-secure EL1, reset
	 *   value (FB bit[9] = 0)
	 * - Do not enable Viaual SError interrupt pending, reset value (VSE bit[8] = 0)
	 * - Do not enable Viaual IRQ interrupt pending, reset value (VI bit[7] = 0)
	 * - Do not enable Viaual FIQ interrupt pending, reset value (VF bit[6] = 0)
	 * - Do not route EL1, EL0 physical asynchronous abort and SError interrupt to EL2, reset
	 *   value (AMO bit[5] = 0)
	 * - Do not route EL1, EL0 physical IRQ interrupt to EL2, reset value (IMO bit[4] = 0)
	 * - Do not route EL1, EL0 physical FRQ interrupt to EL2, reset value (IMO bit[3] = 0)
	 * - Do not enable protected Table Walk, reset value (PTW bit[2] = 0)
	 * - Do not enable data change invalidate by set/way instructions (SWIO bit[1] = 0)
	 * - Do not enable second stage of translation, reset value (VM bit[0] = 0)
	 */
	mov	x1, #0
	orr	x1, x1, #(1 << 31)	// Set RW bit
	msr	HCR_EL2, x1
	isb

	/* All architectural features are not traped to EL2 */
	mov	x0, #0
	msr	CPTR_EL2, x0
	isb

	/* Do not trap any access to coprocessor primary registers CRn to Hypervisor mode */
	mov	x0, #0
	msr	HSTR_EL2, x0
	isb

	/* Hyp Auxiliary Configuration registrer (HACR_EL2) is not implemented in A53 MPCore
	 * Processor revision: r0p4.
	 */

	/* Configure System Control Register SCTLR_EL2:
	 * - Use little endian for data access and stage 1 translation table at EL2 (EE bit[25] = 0)
	 * - Do not force XN permissions for regions with write permissions (WXN bit[19] = 0)
	 * - Enable instructions cache (I bit[12] - 1)
	 * - Enable stack pointer alignment check (SA bit[3] = 1)
	 * - Enable data and unified cache (C bit[2] = 1)
	 * - Disable alignment fault checking (A bit[1] = 0)
	 * - Enable MMU for EL2 (M bit[0] = 1)
	 */
	mov	x1, #0			// Most of the SCTLR_EL2 bits are unknown at reset
	orr	x1, x1, #(1 << 12)	// Set I bit
	orr	x1, x1, #(1 << 3)	// Set SP bit
	orr	x1, x1, #(1 << 2)	// Set C bit
	orr	x1, x1, #(1 << 0)	// Set M bit
	msr	SCTLR_EL2, x1
	dsb	sy
	isb

	/* Jump to EL1 exception level to continue boot proces there. EL1 will be used to run
	 * kernel. Application will be executed in EL0 exception level.
	 */

	/* Set exception return address to InitEL1 */
	adr	x0, InitEL1
	msr	ELR_EL3, x0

	/* Update Saved Program Status Register to change exception level to EL1:
	 * - Disable all interrupts (DAIF bits[9:6] = 0b1111)
	 * - Set AArch64 mode for next exception level (M bit[4] = 0)
	 * - Set next exception level EL1 (M bits[3:2] = 0b01)
	 * - Set EL1 stack pointer to private stack (M bit[0] = 1)
	 */

	mrs	x0, SPSR_EL3
	orr	x0, x0, #(0b1111 << 6)	//Set DAIF bits
	bic	x0, x0, #(0b1111)	//Clear M[4:0] bits
	orr	x0, x0, #(0b01 << 2)	//Set M[3:2] bits
	orr	x0, x0, #(1 << 0)	//Set M[0] bit
	msr	SPSR_EL3, x0

	/* Prepare stack pointer for Exception level EL1 */
	ldr	x0, =EL1_stack
	msr	SP_EL1, x0
	isb

	/* Jump to next exception level */
	eret

#ifndef CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT
.else
	b	error			// Present exception level and selected exception level mismatch
.endif /* EL3 == 1 */
#endif /* CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT */

InitEL1:
#ifndef CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT
.if (EL1_NONSECURE == 1)
#endif /* CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT */
	/* Set vector table base address*/
	ldr	x1, =vector_base
	msr	VBAR_EL1, x1

	/* Do not trap execution of instructions that access Advanced SIMD or Floating-point
	 * registers in any case (FPEN bits[21:20] = 0b11).
	 */
	mrs	x0, CPACR_EL1
	orr	x0, x0, #(0x3 << 20)
	msr	CPACR_EL1, x0
	isb

	/* Clear FPUStatus variable to make sure that it contains current
	 * status of FPU i.e. disabled. In case of a warm restart execution
	 * when bss sections are not cleared, it may contain previously updated
	 * value which does not hold true now.
	 */
#ifndef FREERTOS_BSP
	ldr x0, =FPUStatus
	str xzr, [x0]
#endif
	/* Define stack pointer for current exception level */
	ldr	x2, =EL1_stack
	mov	sp, x2

	/* Disable MMU first */
	mov	x1, #0x0
	msr	SCTLR_EL1, x1
	isb

	TLBI	VMALLE1

	ic	IALLU			// Invalidate I cache to PoU
	bl	invalidate_dcaches
	dsb	sy
	isb

	ldr	x1, =L0Table 		// Get address of level 0 for TTBR0_EL1
	msr	TTBR0_EL1, x1		// Set TTBR0_EL1

	/* Set up memory attributes
	 * This equates to:
	 * 0 = b01000100 = Normal, Inner/Outer Non-Cacheable
	 * 1 = b11111111 = Normal, Inner/Outer WB/WA/RA
	 * 2 = b00000000 = Device-nGnRnE
	 * 3 = b00000100 = Device-nGnRE
	 * 4 = b10111011 = Normal, Inner/Outer WT/WA/RA
	 */
	ldr	x1, =0x000000BB0400FF44
	msr	MAIR_EL1, x1

#if defined (versal)
	/* Set up TCR_EL1
	 * Physical Address Size PS =  100 -> 44bits 16TB
	 * Granual Size TG0 = 00 -> 4KB
	 * size offset of the memory region T0SZ = 20 -> (region size 2^(64-20) = 2^44)
	 */
	ldr	x1, =0x485800514
#else
	/* Set up TCR_EL1
	 * Physical Address Size PS =  010 -> 44bits 16TB
	 * Granual Size TG0 = 00 -> 4KB
	 * size offset of the memory region T0SZ = 24 -> (region size 2^(64-24) = 2^40)
	 */
	ldr	x1, =0x285800518
#endif
	msr	TCR_EL1, x1
	isb

#ifndef CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT
	/* Enable SError Exception for asynchronous abort */
	mrs	x1, DAIF
	bic	x1, x1, #(0x1<<8)
	msr	DAIF, x1
#endif /* CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT */

	/* Configure System Control Register SCTLR_EL1:
	 * - Do not enable access to DC CVAU, DC CIVAC, DC CVAC and IC IVAU instructions, reset
	 *   value (UCI bit[26] = 0)
	 * - Use little endian for data access at EL1 and stage 1 translation table at EL1, EL0
	 *   (EE bit[25] = 0)
	 * - Use little endian for data access at EL0 (EOE bit[24] = 0)
	 * - Do not force XN permissions for regions with write permissions (WXN bit[19] = 0)
	 * - Do not trap WFE instruction executed at EL0 to EL1, reset value (nTWE bit[18] = 1)
	 * - Do not trap WFI instruction executed at EL0 to EL1, reset value (nTWI bit[17] = 1)
	 * - Do not enable access to CTR_EL0 from EL0, reset value(UCT bit[15] = 0)
	 * - Do not enable access to DC ZVA instruction from EL0, reset value (DZE bit[14] = 0)
	 * - Enable instructions cache (I bit[12] - 1)
	 * - Do not enable access to interrup mask from EL0, reset value (UMA bit[9] = 0)
	 * - Enable SETEND instruction, reset value (SED bit[8] = 0)
	 * - Enable IT instruction, reset value (ITD bit[7] = 0)
	 * - Enable CP15 barrier, reset value (CP15BEN bit[5] = 1)
	 * - Enable EL0 stack pointer alignment check, reset value (SAO bit[4] = 1)
	 * - Enable stack pointer alignment check, reset value (SA bit[3] = 1)
	 * - Enable data and unified cache (C bit[2] = 1)
	 * - Disable alignment fault checking, reset value (A bit[1] = 0)
	 * - Enable MMU for EL2 (M bit[0] = 1)
	 */
	mov	x1, #0x0
	orr	x1, x1, #(1 << 18)	// Set nTWE bit
	orr	x1, x1, #(1 << 17)	// Set nTWI bit
	orr	x1, x1, #(1 << 12)	// Set I bit
	orr	x1, x1, #(1 << 5)	// Set CP15 barrier enabled
	orr	x1, x1, #(1 << 4)	// Set SAO bit
	orr	x1, x1, #(1 << 3)	// Set SA bit
	orr	x1, x1, #(1 << 2)	// Set C bit
	//orr	x1, x1, #(1 << 0)	// Set M bit
	msr	SCTLR_EL1, x1
	isb

	/* Continue in EL1. Kernel startup should happen in EL1 exception level. If an application
	 * is aimed to run in EL0 exception level, then kernel should switch to EL0 explicitly.
	 *
	 * All interrupts are still masked (DAIF) to avoid messing in kernel startup.
	 * When kernel is ready, it will unmask interrupts.
	 *
	 * ToDo: Compare with Linux Kernel requirements for CPU configuration in AArch64 mode.
	 *       I'm not sure if e.g. MMU should be enabled at this stage.
	 *       Should SError or Asynchronous abort be disabled?
	 *
	 */
	bl	_startup		// Jump to start
#ifndef CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT
.else
	b	error			// Present exception level and selected exception level mismatch
.endif /* EL1_NONSECURE == 1 */
#endif /* CONFIG_MULTI_LEVEL_EXCEPTIONS_INIT */

error: 	b	error


invalidate_dcaches:

	dmb	ISH
	mrs	x0, CLIDR_EL1		// x0 = CLIDR
	ubfx	w2, w0, #24, #3		// w2 = CLIDR.LoC
	cmp	w2, #0			// LoC is 0?
	b.eq	invalidateCaches_end	// No cleaning required and enable MMU
	mov	w1, #0			// w1 = level iterator

invalidateCaches_flush_level:
	add	w3, w1, w1, lsl #1	// w3 = w1 * 3 (right-shift for cache type)
	lsr	w3, w0, w3		// w3 = w0 >> w3
	ubfx	w3, w3, #0, #3		// w3 = cache type of this level
	cmp	w3, #2			// No cache at this level?
	b.lt	invalidateCaches_next_level

	lsl	w4, w1, #1
	msr	CSSELR_EL1, x4		// Select current cache level in CSSELR
	isb				// ISB required to reflect new CSIDR
	mrs	x4, CCSIDR_EL1		// w4 = CSIDR

	ubfx	w3, w4, #0, #3
	add	w3, w3, #2		// w3 = log2(line size)
	ubfx	w5, w4, #13, #15
	ubfx	w4, w4, #3, #10		// w4 = Way number
	clz	w6, w4			// w6 = 32 - log2(number of ways)

invalidateCaches_flush_set:
	mov	w8, w4			// w8 = Way number
invalidateCaches_flush_way:
	lsl	w7, w1, #1		// Fill level field
	lsl	w9, w5, w3
	orr	w7, w7, w9		// Fill index field
	lsl	w9, w8, w6
	orr	w7, w7, w9		// Fill way field
	dc	CISW, x7		// Invalidate by set/way to point of coherency
	subs	w8, w8, #1		// Decrement way
	b.ge	invalidateCaches_flush_way
	subs	w5, w5, #1		// Descrement set
	b.ge	invalidateCaches_flush_set

invalidateCaches_next_level:
	add	w1, w1, #1		// Next level
	cmp	w2, w1
	b.gt	invalidateCaches_flush_level

invalidateCaches_end:
	ret

.end
/**
* @} End of "addtogroup a53_64_boot_code".
*/
