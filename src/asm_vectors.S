/******************************************************************************
* Copyright (c) 2014 - 2021 Xilinx, Inc.  All rights reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*****************************************************************************/
/**
* @file asm_vectors.S
*
* This file contains the initial vector table for the Cortex A53 processor
*
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who     Date     Changes
* ----- ------- -------- ---------------------------------------------------
* 5.00	pkp	05/21/14 Initial version
* 6.02  pkp	12/21/16 Added support for floating point access
* 6.02  pkp	01/22/17 Added support for EL1 non-secure and hypervisor
*			 baremetal guest
* 6.4   mus     06/14/17 Fixed bug in IRQInterruptHandler code snippet,
*                        which checks for the FPEN bit of CPACR_EL1
* 6.6   mus     01/19/18 Added isb after writing to the cpacr_el1/cptr_el3,
*                        to ensure enabling/disabling of floating-point unit
*                        is completed, before any subsequent instruction.
* 7.5   mus  05/20/21 Fixed speculative execution past ERET and BR instructions.
*                     As per CVE-2020-13844, Cortex-A72 is affected with
*                     vulnearability, hence changes are targeted only for Cortex-A72.
*                     It fixes CR#1083649.
* 7.7.  asa     03/22/22  Updated FIQ handler to also handle floating/SIMD context.
*
* </pre>
*
* @note
*
* None.
*
******************************************************************************/

/* TODO: asm_vectors.S should only manage preparation of "C" code execution.
 * It should make checks/changes in execution context when it is difficult
 * to deliver that in "C" code e.g. check if stack limist are not exceeded.
 */
#include "bspconfig.h"
.include "esr.S"

.org 0
.text

.globl _boot
.globl _vector_table
.globl _reset_vector
.global _STACK_SIZE

.globl FIQInterrupt
.globl IRQInterrupt
.globl SErrorInterrupt
.globl SynchronousInterrupt
.globl FPUStatus

.set EL_OFFSET, 0x2
.set CURR_EL1, (0x1 << EL_OFFSET)
.set CURR_EL2, (0x2 << EL_OFFSET)
.set CURR_EL3, (0x3 << EL_OFFSET)

.set STACK_SIZE, _STACK_SIZE
/* Number of registers that could be stored during preparation of exception handler call.
 * Count of registers is tightly connected with ARM64 ABI function call.
 */
.set PROC_CALL_REGS_NUM, 22
/* It is assumed that we operate in aarch64 mode, hece register size is 8 bytes */
.set PROC_CALL_REGS_SIZE, (0x8 * PROC_CALL_REGS_NUM)
/*
 * FPUContextSize is the size of the array where floating point registers are
 * stored when required. The default size corresponds to the case when there is no
 * nested interrupt. If there are nested interrupts in application which are using
 * floating point operation, the size of FPUContextSize need to be increased as per
 * requirement
 */

.set FPUContextSize, 528

/* The macro assumes that stack is already prepared to store all procedure call registers.
 * If not then stack is overflowed.
 */
.macro save_proc_call_registers
	/* x0-x7 registers store function call arguments. They may also by used for storage of
	 * temporary values. These registers must be saved when ISR starts to make possible
	 * restore of former execution state.
	 */
	stp	x0, x1, [sp, #0x10 * 0]
	stp	x2, x3, [sp, #0x10 * 1]
	stp	x4, x5, [sp, #0x10 * 2]
	stp	x6, x7, [sp, #0x10 * 3]

	/* x8 register is a special to store indirect results. It must be stored to restore
	 * former execution state.
	 *
	 * x9-x15 are temporary registers that are caller saved.
	 */
	stp	x8, x9, [sp, #0x10 * 4]
	stp	x10, x11, [sp, #0x10 * 5]
	stp	x12, x13, [sp, #0x10 * 6]
	stp	x14, x15, [sp, #0x10 * 7]

	/* x16, x17 are special registers, intra procedure call temporary registers. They may be
	 * used for call veneers or as temporary intermediate values between subrutine calls.
	 * x18 is a platform register and is reserved for use of platform ABI. In other case it is
	 * temporary register.
	 *
	 * NOTE: x19 is a callee saved register. It is used here to make sure the SP holds a value
	 *       aligned to 16 bytes.
	 */
	stp	x16, x17, [sp, #0x10 * 8]
	stp 	x18, x19, [sp, #0x10 * 9]

	/* x20-x28 are calee saved registers. Make sure the assembler ISR does not use them or
	 * saver appropriate register on stack.
	 */

	/* x29 (FP) and x30(LR) registers are always stored at the end of a preparation for
	 * ISR execution.
	 */
	stp 	x29, x30, [sp, #0x10 * 10]

	/* Prepare FP in case an assemblu ISR requires to use it as base for access to data stored
	 * on a stack, hence the FP(x29) should point to a base of a function call frame.
	 *
	 * NOTE: This operation may be optimized out in case the stack will be left in unchanged
	 *       state by assembly ISR code.
	 */
	mov	x29, SP
.endm

.macro save_registers
	/* x0-x7 registers store function call arguments. They may also by used for storage of
	 * temporary values. These registers must be saved when ISR starts to make possible
	 * restore of former execution state.
	 */
	stp	x0, x1, [sp, #-0x10]!
	stp	x2, x3, [sp, #-0x10]!
	stp	x4, x5, [sp, #-0x10]!
	stp	x6, x7, [sp, #-0x10]!

	/* x8 register is a special to store indirect results. It must be stored to restore
	 * former execution state.
	 *
	 * x9-x15 are temporary registers that are caller saved.
	 */
	stp	x8, x9, [sp, #-0x10]!
	stp	x10, x11, [sp, #-0x10]!
	stp	x12, x13, [sp, #-0x10]!
	stp	x14, x15, [sp, #-0x10]!

	/* x16, x17 are special registers, intra procedure call temporary registers. They may be
	 * used for call veneers or as temporary intermediate values between subrutine calls.
	 * x18 is a platform register and is reserved for use of platform ABI. In other case it is
	 * temporary register.
	 *
	 * NOTE: x19 is a callee saved register. It is used here to make sure the SP holds a value
	 *       aligned to 16 bytes.
	 */
	stp	x16, x17, [sp, #-0x10]!
	stp 	x18, x19, [sp, #-0x10]!

	/* x20-x28 are calee saved registers. Make sure the assembler ISR does not use them or
	 * saver appropriate register on stack.
	 */

	/* x29 (FP) and x30(LR) registers are always stored at the end of a preparation for
	 * ISR execution.
	 */
	stp 	x29, x30, [sp, #-0x10]!

	/* Prepare FP in case an assemblu ISR requires to use it as base for access to data stored
	 * on a stack, hence the FP(x29) should point to a base of a function call frame.
	 *
	 * NOTE: This operation may be optimized out in case the stack will be left in unchanged
	 *       state by assembly ISR code.
	 */
	mov	x29, SP
.endm

.macro restore_registers
	/* Restore SP, just in case an assembly ISR code left it in different state than it was
	 * at end of an prologue.
	 *
	 * NOTE: This operation may be optimized out in case the stack is unchanged by assembly ISR
	 *       code.
	 */
	mov	SP, x29
	/* Restore registers from stack, so in reverse order of storeregister macro.
	 * FP and LR registers at first.
	 *
	 * NOTE: Restore of LR does not cause return and it will not be used as a return address.
	 *       The macro is suposed to be used in ISR context, hence the return address is stored
	 *       in ELR_ELx register. This operation restores LR to the state is was when exception
	 *       happened. It makes the event transpared to the code that was interrupted.
	 */
	ldp 	x29, x30, [sp], #0x10
	/* x20-x28 callee saved registers must be restored in case they were used by
	 * assembler ISR code. C/C++ handler will restore them by compiled code.
	 *
	 * NOTE: x19 is also callee saved register but it was saved to make sure the SP is correctly
	 *       aligned.
	 *
	 * Restore all other saved registers.
	 */
	ldp 	x18, x19, [sp], #0x10
	ldp	x16, x17, [sp], #0x10
	ldp	x14, x15, [sp], #0x10
	ldp	x12, x13, [sp], #0x10
	ldp	x10, x11, [sp], #0x10
	ldp	x8, x9, [sp], #0x10
	ldp	x6, x7, [sp], #0x10
	ldp	x4, x5, [sp], #0x10
	ldp	x2, x3, [sp], #0x10
	ldp	x0,x1, [sp], #0x10
.endm

.macro save_float_registers

/* Load the floating point context array address from FPUContextBase */
	ldr	x1,=FPUContextBase
	ldr	x0, [x1]

/* Save all the floating point register to the array */
	stp	q0, q1, [x0], #0x20
	stp	q2, q3, [x0], #0x20
	stp	q4, q5, [x0], #0x20
	stp	q6, q7, [x0], #0x20
	stp	q8, q9, [x0], #0x20
	stp	q10, q11, [x0], #0x20
	stp	q12, q13, [x0], #0x20
	stp	q14, q15, [x0], #0x20
	stp	q16, q17, [x0], #0x20
	stp	q18, q19, [x0], #0x20
	stp	q20, q21, [x0], #0x20
	stp	q22, q23, [x0], #0x20
	stp	q24, q25, [x0], #0x20
	stp	q26, q27, [x0], #0x20
	stp	q28, q29, [x0], #0x20
	stp	q30, q31, [x0], #0x20
	mrs	x2, FPCR
	mrs	x3, FPSR
	stp	x2, x3, [x0], #0x10

/* Save current address of floating point context array to FPUContextBase */
	str	x0, [x1]
.endm

.macro restore_float_registers

/* Restore the address of floating point context array from FPUContextBase */
	ldr	x1, =FPUContextBase
	ldr	x0, [x1]

/* Restore all the floating point register from the array */
	ldp	x2, x3, [x0, #-0x10]!
	msr	FPCR, x2
	msr	FPSR, x3
	ldp	q30, q31, [x0, #-0x20]!
	ldp	q28, q29, [x0, #-0x20]!
	ldp	q26, q27, [x0, #-0x20]!
	ldp	q24, q25, [x0, #-0x20]!
	ldp	q22, q23, [x0, #-0x20]!
	ldp	q20, q21, [x0, #-0x20]!
	ldp	q18, q19, [x0, #-0x20]!
	ldp	q16, q17, [x0, #-0x20]!
	ldp	q14, q15, [x0, #-0x20]!
	ldp	q12, q13, [x0, #-0x20]!
	ldp	q10, q11, [x0, #-0x20]!
	ldp	q8, q9, [x0, #-0x20]!
	ldp	q6, q7, [x0, #-0x20]!
	ldp	q4, q5, [x0, #-0x20]!
	ldp	q2, q3, [x0, #-0x20]!
	ldp	q0, q1, [x0, #-0x20]!

/* Save current address of floating point context array to FPUContextBase */
	str	x0, [x1]
.endm

.macro exception_return
	eret
#if defined (versal)
	dsb nsh
	isb
#endif
.endm

.macro get_esr_elx
	/* Check current exception level to get proper exceptions syndrom register */
	mrs	x0, currentEL
	cmp	x0, CURR_EL2
	blt	2f
	bgt	3f
1:
	mrs	x0, ESR_EL2
	b	4f
2:
	mrs	x0, ESR_EL1
	b	4f
3:
	mrs	x0, ESR_EL3
4:
	/* Continue execution */
.endm

.macro get_cptr_elx
	/* Check current exception level to ger proper exceptions syndrom register */
	mrs	x0, currentEL
	cmp	x0, CURR_EL2
	blt	2f
	bgt	3f
1:
	mrs	x0, CPTR_EL2
	bic	x0, x0, #(0x1<<10)
	msr	CPTR_EL2, x0
	b	4f
2:
	mrs	x0, CPACR_EL1
	bic	x0, x0, #(0x1<<20)
	msr	CPACR_EL1, x0
	b	4f
3:
	mrs	x0, CPTR_EL3
	bic	x0, x0, #(0x1<<10)
	msr	CPTR_EL3, x0
4:
	/* Continue execution */
.endm


.org 0

.section .vectors, "ax"

_reset_vector:
/*
 * if application is built for XEN GUEST as EL1 Non-secure following image
 * header is required by XEN.
 */
.if (HYP_GUEST == 1)

	/* Valid Image header.  */
	/* HW reset vector.  */
	ldr	x16, =_boot
	br	x16
#if defined (versal)
	dsb nsh
	isb
#endif
	/* text offset.  */
	.dword	0
	/* image size.  */
	.dword	0
	/* flags.  */
	.dword	8
	/* RES0  */
	.dword	0
	.dword	0
	.dword	0

	/* magic  */
	.dword	0x644d5241
	/* RES0  */
	.dword	0
	/* End of Image header.  */
.endif
	b	_boot

/* VBAR_ELx register has reserved bits [10:0], vector base address is store in bits [63:11].
 * The address of vector table must be aligned to the 11 bits bounday. In other case VBAR_ELx will
 * always be wrong.
 */
.p2align 11

_vector_table:
.set	VBAR, _vector_table
.org VBAR

/* Target and source on the same exception level with source SP = SP_EL0 */
.org (VBAR + 0x000)
	b	SynchronousInterruptHandler
.org (VBAR + 0x080)
	b	IRQInterruptHandler
.org (VBAR + 0x100)
	b	FIQInterruptHandler
.org (VBAR + 0x180)
	b	SErrorInterruptHandler

/* Target and source on the same exception level with source SP = SP_ELx */
.org (VBAR + 0x200)
	b	SynchronousInterruptHandler
.org (VBAR + 0x280)
	b	IRQInterruptHandler
.org (VBAR + 0x300)
	b	FIQInterruptHandler
.org (VBAR + 0x380)
	b	SErrorInterruptHandler

/* Source is at lower exception level running AArch64 */
.org (VBAR + 0x400)
	b	SynchronousInterruptHandler
.org (VBAR + 0x480)
	b	IRQInterruptHandler
.org (VBAR + 0x500)
	b	FIQInterruptHandler
.org (VBAR + 0x580)
	b	SErrorInterruptHandler

/* Source is at lower exception level running AArch32 */
.org (VBAR + 0x600)
	b	SynchronousInterruptHandler
.org (VBAR + 0x680)
	b	IRQInterruptHandler
.org (VBAR + 0x700)
	b	FIQInterruptHandler
.org (VBAR + 0x780)
	b	SErrorInterruptHandler

_vector_table_el1:
.set	VBAR_EL1, _vector_table_el1
.org VBAR_EL1

/* Target and source on the same exception level with source SP = SP_EL0 */
.org (VBAR_EL1 + 0x000)
	b	SynchronousInterruptHandlerEL1
.org (VBAR_EL1 + 0x080)
	b	IRQInterruptHandler
.org (VBAR_EL1 + 0x100)
	b	FIQInterruptHandler
.org (VBAR_EL1 + 0x180)
	b	SErrorInterruptHandler

/* Target and source on the same exception level with source SP = SP_ELx */
.org (VBAR_EL1 + 0x200)
	b	SynchronousInterruptHandlerEL1
.org (VBAR_EL1 + 0x280)
	b	IRQInterruptHandler
.org (VBAR_EL1 + 0x300)
	b	FIQInterruptHandler
.org (VBAR_EL1 + 0x380)
	b	SErrorInterruptHandler

/* Source is at lower exception level running AArch64 */
.org (VBAR_EL1 + 0x400)
	b	SynchronousInterruptHandlerEL1
.org (VBAR_EL1 + 0x480)
	b	IRQInterruptHandler
.org (VBAR_EL1 + 0x500)
	b	FIQInterruptHandler
.org (VBAR_EL1 + 0x580)
	b	SErrorInterruptHandler

/* Source is at lower exception level running AArch32 */
.org (VBAR_EL1 + 0x600)
	b	SynchronousInterruptHandlerEL1
.org (VBAR_EL1 + 0x680)
	b	IRQInterruptHandler
.org (VBAR_EL1 + 0x700)
	b	FIQInterruptHandler
.org (VBAR_EL1 + 0x780)
	b	SErrorInterruptHandler

SynchronousInterruptHandler:
	save_registers

	get_esr_elx

	lsr	x0, x0, #ESR_ELX_EC_OFFSET
	and	x0, x0, #ESR_ELX_EC_MASK
	mov	x1, #ESR_ELX_EC_ASIMD
	cmp	x0, x1
/* If exception is not caused by floating point access go to synchronous handler */
	bne	.Lsynchronoushandler

/* If excpetion occurred due to floating point access, Enable the floating point
 * access i.e. do not trap floating point instruction
 */
	get_cptr_elx
	isb

/* If the floating point access was previously enabled, store FPU context
 * registers(storefloat).
 */
	ldr	x0, =FPUStatus
	ldrb	w1,[x0]
	cbnz	w1, .Lstorefloat
/*
 * If the floating point access was not enabled previously, save the status of
 * floating point accessibility i.e. enabled and store floating point context
 * array address(FPUContext) to FPUContextBase.
 */
	mov	w1, #0x1
	strb	w1, [x0]
	ldr	x0, =FPUContext
	ldr	x1, =FPUContextBase
	str	x0,[x1]
	b	.Lrestorecontext
.Lstorefloat:
	save_float_registers
/* No further handling of exeption related with floating point.
 * Just a placeholder for future.
 */
	b	.Lrestorecontext
.Lsynchronoushandler:
	bl	SynchronousInterrupt
.Lrestorecontext:
	restore_registers
	exception_return

SynchronousInterruptHandlerEL1:
	/* ToDO: change beginning of the label, to macro. It should be a common code for all
	 *       exception handlers. This part should fit into 32 instructions in exception
	 *       handlers memory.
	 */

	/* In very beginning, check if there is still space on a stack to store registers.
	 * If not, go to handling of bad stack.
	 * This should fit into exception vector.
	 * Then branch to continuation of an exception, eg. common code that prepares handling
	 * of an exception in "C" language.
	 */

	/* Make a space on stack to store all procedure call registers */
	sub	sp, sp, #PROC_CALL_REGS_SIZE

	/* This is a very basic check if a stack overflowed by attempt to store procedure call
	 * registers. It does not prevent from all stack overflows. There are two assumptions:
	 * - stack size is a power of two (for aarch64 SP must be 16 bytes aligned, hence size other
	 *   than multiple of 16 byte does not make sense).
	 * - stack base is aligned on a boundary that is double STACK_SIZE, however bottom of the
	 *   stack (highest address) is at STACK_BASE + STACK_SIZE address.
	 *
	 * The overflow check is: SP & STACK_SIZE.
	 *
	 * Assume that STACK_SIZE = 0x2000.
	 *
	 * If there is no overflow the result of this check is zero.
	 * For example: SP=0x410040FF, STACK_TOP = 0x41006000 STACK_BASE = 0x41004000,
	 * BASE_OFFSET = 0x000000FF.
	 * SP & 0x00002000 = 0x00000000.
	 *
	 * If there is an overflow not larger than one STACK_SIZE, then the result of the check
	 * is non zero value.
	 * For example: SP=0x410040FF, STACK_TOP = 0x41006000 STACK_BASE = 0x41004000,
	 * BASE_OFFSET = 0x000000FF, STACK_SUBTRACT_SIZE = 0x1FF.
	 * SP_AFTER_SUBTRACT = 0x41003F00.
	 * SP_AFTER_SUBTRACT & 0x00002000 = 0x00002000.
	 *
	 * If stack has overflown more than double stack size to next memory area with valid
	 * alignment, then the check will not detect is.
	 * For example: SP=0x410080FF, STACK_TOP = 0x4100A000 STACK_BASE = 0x41008000,
	 * BASE_OFFSET = 0x000000FF, STACK_SUBTRACT_SIZE = 0x4010.
	 * SP_AFTER_SUBTRACT = 0x410040EF.
	 * SP_AFTER_SUBTRACT & 0x00002000 = 0x00000000.
	 */

	add 	sp, sp, x0	// sp' = sp + x0
	sub	x0, sp, x0	// x0' = sp' - x0 = (sp + x0) - x0 = sp
	tbnz	x0, #0xC, BadStack
	sub	x0, sp, x0	// x0'' = sp' - x0' = (sp + x0) - sp = x0
	sub	sp, sp, x0	// x0'' = sp' + x0'' = (sp + x0) - x0 = sp

	save_proc_call_registers

	mrs	x0, ESR_EL1
	lsr	x0, x0, #ESR_ELX_EC_OFFSET
	and	x0, x0, #ESR_ELX_EC_MASK
	mov	x1, #ESR_ELX_EC_ASIMD
	cmp	x0, x1
/* If exception is not caused by floating point access go to synchronous handler */
	bne	.Lsynchronoushandler_EL1

/* If excpetion occurred due to floating point access, Enable the floating point
 * access i.e. do not trap floating point instruction
 */
	mrs	x1, CPACR_EL1
	isb

/* If the floating point access was previously enabled, store FPU context
 * registers(storefloat).
 */
	ldr	x0, =FPUStatus
	ldrb	w1,[x0]
	cbnz	w1, .Lstorefloat_EL1
/*
 * If the floating point access was not enabled previously, save the status of
 * floating point accessibility i.e. enabled and store floating point context
 * array address(FPUContext) to FPUContextBase.
 */
	mov	w1, #0x1
	strb	w1, [x0]
	ldr	x0, =FPUContext
	ldr	x1, =FPUContextBase
	str	x0,[x1]
	b	.Lrestorecontext_EL1
.Lstorefloat_EL1:
	save_float_registers
/* No further handling of exeption related with floating point.
 * Just a placeholder for future.
 *
 * Actually I don't know why is it implemented this way in original BSP delivered by Xilinx.
 */
	b	.Lrestorecontext
.Lsynchronoushandler_EL1:
	bl	SynchronousInterrupt
.Lrestorecontext_EL1:
	restore_registers
	exception_return

IRQInterruptHandler:

	save_registers
/* Save the status of SPSR, ELR and CPTR to stack */
 .if (EL3 == 1)
	mrs 	x0, CPTR_EL3
	mrs 	x1, ELR_EL3
	mrs	x2, SPSR_EL3
.else
	mrs 	x0, CPACR_EL1
	mrs 	x1, ELR_EL1
	mrs	x2, SPSR_EL1
.endif
	stp	x0, x1, [sp,#-0x10]!
	str	x2, [sp,#-0x10]!

/* Trap floating point access */
 .if (EL3 == 1)
	mrs	x1,CPTR_EL3
	orr	x1, x1, #(0x1<<10)
	msr	CPTR_EL3, x1
.else
	mrs	x1,CPACR_EL1
	bic	x1, x1, #(0x1<<20)
	msr	CPACR_EL1, x1
.endif
	isb

	bl	IRQInterrupt
/*
 * If floating point access is enabled during interrupt handling,
 * restore floating point registers.
 */

 .if (EL3 == 1)
	mrs	x0, CPTR_EL3
	ands	x0, x0, #(0x1<<10)
	bne	RestorePrevState
.else
	mrs	x0,CPACR_EL1
	ands	x0, x0, #(0x1<<20)
	beq	RestorePrevState
.endif

	restore_float_registers

/* Restore the status of SPSR, ELR and CPTR from stack */
RestorePrevState:
	ldr	x2,[sp],0x10
	ldp	x0, x1, [sp],0x10
 .if (EL3 == 1)
	msr	CPTR_EL3, x0
	msr	ELR_EL3, x1
	msr	SPSR_EL3, x2
.else
	msr	CPACR_EL1, x0
	msr	ELR_EL1, x1
	msr	SPSR_EL1, x2
.endif
	restore_registers
	exception_return

FIQInterruptHandler:

  save_registers
/* Save the status of SPSR, ELR and CPTR to stack */
 .if (EL3 == 1)
	mrs 	x0, CPTR_EL3
	mrs 	x1, ELR_EL3
	mrs	x2, SPSR_EL3
.else
	mrs 	x0, CPACR_EL1
	mrs 	x1, ELR_EL1
	mrs	x2, SPSR_EL1
.endif
	stp	x0, x1, [sp,#-0x10]!
	str	x2, [sp,#-0x10]!

/* Trap floating point access */
 .if (EL3 == 1)
	mrs	x1,CPTR_EL3
	orr	x1, x1, #(0x1<<10)
	msr	CPTR_EL3, x1
.else
	mrs	x1,CPACR_EL1
	bic	x1, x1, #(0x1<<20)
	msr	CPACR_EL1, x1
.endif
	isb
	bl	FIQInterrupt
	/*
 * If floating point access is enabled during interrupt handling,
 * restore floating point registers.
 */

 .if (EL3 == 1)
	mrs	x0, CPTR_EL3
	ands	x0, x0, #(0x1<<10)
	bne	RestorePrevStatefiq
.else
	mrs	x0,CPACR_EL1
	ands	x0, x0, #(0x1<<20)
	beq	RestorePrevStatefiq
.endif

	restore_float_registers

	/* Restore the status of SPSR, ELR and CPTR from stack */
RestorePrevStatefiq:
	ldr	x2,[sp],0x10
	ldp	x0, x1, [sp],0x10
 .if (EL3 == 1)
	msr	CPTR_EL3, x0
	msr	ELR_EL3, x1
	msr	SPSR_EL3, x2
.else
	msr	CPACR_EL1, x0
	msr	ELR_EL1, x1
	msr	SPSR_EL1, x2
.endif
	restore_registers
	exception_return

SErrorInterruptHandler:

	save_registers

	bl	SErrorInterrupt

	restore_registers

	exception_return

BadStack:
	/* Stop in a infinite loop until there is other proper handling of stack overflow */
	b	.

.align 8
/* Array to store floating point registers */
FPUContext: .skip FPUContextSize

/* Stores address for floating point context array */
FPUContextBase: .skip 8

FPUStatus: .skip 1

.end
