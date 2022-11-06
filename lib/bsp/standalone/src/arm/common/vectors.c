/******************************************************************************
* Copyright (c) 2009 - 2021 Xilinx, Inc.  All rights reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/

/*****************************************************************************/
/**
* @file vectors.c
*
* This file contains the C level vectors for the ARM Cortex A9 core.
*
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who  Date     Changes
* ----- ---- -------- ---------------------------------------------------
* 1.00a ecm  10/20/09 Initial version, moved over from bsp area
* 6.0   mus  27/07/16 Consolidated vectors for a53,a9 and r5 processor
*                     and added UndefinedException for a53 32 bit and r5
*                     processor
* 7.7	sk   03/02/22 Move XExc_VectorTableEntry structure to xil_exception.h
* 		      header file to fix misra_c_2012_rule_5_6 violation.
* 7.7	sk   03/02/22 Move XExc_VectorTableEntry declaration to xil_exception.h
* 		      header file to fix misra_c_2012_rule_8_4 violation.
* </pre>
*
******************************************************************************/
/***************************** Include Files *********************************/

#include "xil_exception.h"
#include "vectors.h"
#include "asm_sysreg.h"
#include "esr.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/

/************************** Function Prototypes ******************************/


/*****************************************************************************/
/**
*
* This is the C level wrapper for the FIQ interrupt called from the vectors.s
* file.
*
* @return	None.
*
******************************************************************************/
void FIQInterrupt(void)
{
	XExc_VectorTable[XIL_EXCEPTION_ID_FIQ_INT].Handler(XExc_VectorTable[
					XIL_EXCEPTION_ID_FIQ_INT].Data);
}

/*****************************************************************************/
/**
*
* This is the C level wrapper for the IRQ interrupt called from the vectors.s
* file.
*
* @return	None.
*
******************************************************************************/
void IRQInterrupt(void)
{
	XExc_VectorTable[XIL_EXCEPTION_ID_IRQ_INT].Handler(XExc_VectorTable[
					XIL_EXCEPTION_ID_IRQ_INT].Data);
}

#if !defined (__aarch64__)
/*****************************************************************************/
/**
*
* This is the C level wrapper for the Undefined exception called from the
* vectors.s file.
*
* @return	None.
*
******************************************************************************/
void UndefinedException(void)
{
	XExc_VectorTable[XIL_EXCEPTION_ID_UNDEFINED_INT].Handler(XExc_VectorTable[
					XIL_EXCEPTION_ID_UNDEFINED_INT].Data);
}

/*****************************************************************************/
/**
*
* This is the C level wrapper for the SW Interrupt called from the vectors.s
* file.
*
* @return	None.
*
******************************************************************************/
void SWInterrupt(void)
{
	XExc_VectorTable[XIL_EXCEPTION_ID_SWI_INT].Handler(XExc_VectorTable[
					XIL_EXCEPTION_ID_SWI_INT].Data);
}

/*****************************************************************************/
/**
*
* This is the C level wrapper for the DataAbort Interrupt called from the
* vectors.s file.
*
* @return	None.
*
******************************************************************************/
void DataAbortInterrupt(void)
{
	XExc_VectorTable[XIL_EXCEPTION_ID_DATA_ABORT_INT].Handler(
		XExc_VectorTable[XIL_EXCEPTION_ID_DATA_ABORT_INT].Data);
}

/*****************************************************************************/
/**
*
* This is the C level wrapper for the PrefetchAbort Interrupt called from the
* vectors.s file.
*
* @return	None.
*
******************************************************************************/
void PrefetchAbortInterrupt(void)
{
	XExc_VectorTable[XIL_EXCEPTION_ID_PREFETCH_ABORT_INT].Handler(
		XExc_VectorTable[XIL_EXCEPTION_ID_PREFETCH_ABORT_INT].Data);
}
#else

/*****************************************************************************/
/**
*
* This is the C level wrapper for the Synchronous Interrupt called from the vectors.s
* file.
*
* @return	None.
*
******************************************************************************/
void SynchronousInterrupt(void)
{
	uint64_t esr = SYSREG_READ(esr_el1);

	switch(esr_elx_ec_value_get(esr)) {
	case ESR_ELX_EC_UNKNOWN:
	case ESR_ELX_EC_WFX:
	/* Unallocated 0b000010 (0x2) */
	case ESR_ELX_EC_CP15_MR:
	case ESR_ELX_EC_CP15_MRR:
	case ESR_ELX_EC_CP14_MR:
	case ESR_ELX_EC_CP14_LS:
	case ESR_ELX_EC_ASIMD:
	case ESR_ELX_EC_CP10_ID:
	case ESR_ELX_EC_PAC:
	case ESR_ELX_EC_LS64:
	/* Unallocated 0b001011 (0xB)*/
	case ESR_ELX_EC_CP14_MRR:
	case ESR_ELX_EC_BTI:
	case ESR_ELX_EC_ILL:
	/* Unallocated 0b001111 - 0b010000 (0xF - 0x10) */
	case ESR_ELX_EC_SVC_32:
	case ESR_ELX_EC_HVC_32:
	case ESR_ELX_EC_SMC_32:
	/* Unallocated 0b010100 (0x14) */
	case ESR_ELX_EC_SVC_64:
	case ESR_ELX_EC_HVC_64:
	case ESR_ELX_EC_SMC_64:
	case ESR_ELX_EC_SYS_64:
	case ESR_ELX_EC_SVE_64:
	case ESR_ELX_EC_ERET:
	/* Unallocated 0b011011 (0x1B) */
	case ESR_ELX_EC_FPAC:
	case ESR_ELX_EC_SME:
	/* Unallocated 0b011110 (0x1E)*/
	case ESR_ELX_EC_IMP_DEF:
	case ESR_ELX_EC_IABT_LOW:
	case ESR_ELX_EC_IABT_CUR:
	case ESR_ELX_EC_PC_ALIGN:
	/* Unallocated 0b100011 (0x23) */
	case ESR_ELX_EC_DABT_LOW:
	case ESR_ELX_EC_DABT_CUR:
	case ESR_ELX_EC_SP_ALIGN:
	case ESR_ELX_EC_MOPS:
	case ESR_ELX_EC_FP_32:
	/* Unallocated 0b101001 - 0b101011 (0x29 - 0x2B) */
	case ESR_ELX_EC_FP_64:
	/* Unallocated 0b101101 - 0b101110 (0x2D - 0x2E) */
	case ESR_ELX_EC_SERROR:
	case ESR_ELx_EC_BREAKPT_LOW:
	case ESR_ELx_EC_BREAKPT_CUR:
	case ESR_ELx_EC_SW_STEP_LOW:
	case ESR_ELx_EC_SW_STEP_CUR:
	case ESR_ELx_EC_WATCHPT_LOW:
	case ESR_ELx_EC_WATCHPT_CUR:
	/* Unallocated: 0b110110 - 0b110111 (0x36 - 0x37) */
	case ESR_ELx_EC_BKPT32:
	/* Unallocated: 0b1101001 (0x39) */
	case ESR_ELx_EC_VECTOR32:
	/* Unallocated: 0b111011 (0x3B) */
	case ESR_ELx_EC_BRK64:
	/* Unallocated: 0b111101 - 0b111111 (0x3D - 0x3F) */
	case ESR_ELx_EC_MAX:
		break;
	}

	XExc_VectorTable[XIL_EXCEPTION_ID_SYNC_INT].Handler(XExc_VectorTable[
					XIL_EXCEPTION_ID_SYNC_INT].Data);
}

/*****************************************************************************/
/**
*
* This is the C level wrapper for the SError Interrupt called from the
* vectors.s file.
*
* @return	None.
*
******************************************************************************/
void SErrorInterrupt(void)
{
	XExc_VectorTable[XIL_EXCEPTION_ID_SERROR_ABORT_INT].Handler(
		XExc_VectorTable[XIL_EXCEPTION_ID_SERROR_ABORT_INT].Data);
}

#endif
