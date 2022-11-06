/******************************************************************************
* Copyright (c) 2022 Piotr Pryga - All rights reserved.
*
* Author: Piotr Pryga <pryga.piotr@outlook.com>
* SPDX-License-Identifier: MIT
******************************************************************************/
/*****************************************************************************/
/**
* @file esr.h
*
* This file contains code that supports use of Exception Syndrome Register.
******************************************************************************/
#include <stdint.h>

#ifndef ESR_H

/* Constants related with Exception Syndrome Register ELx. */
#define ESR_ELX_EC_MASK,   0x3F
#define ESR_ELX_EC_OFFSET, 26

static inline uint64_t esr_elx_ec_value_get(uint64_t esr_value)
{
	return ((esr_value >> ESR_ELX_EC_OFFSET) & EST_ElX_EX_MASK);
}

/* Exception classes constants.
 *
 * NOTE: As of now, only SVC related codes are required.
 *       All other exception classes go into one handling path.
 */
#define ESR_ELX_EC_UNKNOWN,     (0b000000) /* 0x0 */
#define ESR_ELX_EC_WFX,         (0b000001) /* 0x1 */
/* Unallocated 0b000010 (0x2) */
#define ESR_ELX_EC_CP15_MR,     (0b000011) /* 0x3 */
#define ESR_ELX_EC_CP15_MRR,    (0b000100) /* 0x4 */
#define ESR_ELX_EC_CP14_MR,     (0b000101) /* 0x5 */
#define ESR_ELX_EC_CP14_LS,     (0b000110) /* 0x6 */
#define ESR_ELX_EC_ASIMD,       (0b000111) /* 0x7 */
#define ESR_ELX_EC_CP10_ID,     (0b001000) /* 0x8 - EL2 only*/
#define ESR_ELX_EC_PAC,         (0b001001) /* 0x9 - EL2 and above - FEAT_PAuth required */
#define ESR_ELX_EC_LS64,        (0b001010) /* 0xA - FEAT_LS64 required */
/* Unallocated 0b001011 (0xB)*/
#define ESR_ELX_EC_CP14_MRR,    (0b001100) /* 0xC */
#define ESR_ELX_EC_BTI,         (0b001101) /* 0xD - FEAT_BTI required */
#define ESR_ELX_EC_ILL,         (0b001110) /* 0xE */
/* Unallocated 0b001111 - 0b010000 (0xF - 0x10) */
#define ESR_ELX_EC_SVC_32,      (0b010001) /* 0x11 */
#define ESR_ELX_EC_HVC_32,      (0b010010) /* 0x12 - EL2 only */
#define ESR_ELX_EC_SMC_32,      (0b010011) /* 0x13 - EL2 or above */
/* Unallocated 0b010100 (0x14) */
#define ESR_ELX_EC_SVC_64,      (0b010101) /* 0x15 */
#define ESR_ELX_EC_HVC_64,      (0b010110) /* 0x16 - EL2 only*/
#define ESR_ELX_EC_SMC_64,      (0b010111) /* 0x17 - EL2 or above */
#define ESR_ELX_EC_SYS_64,      (0b011000) /* 0x18 */
#define ESR_ELX_EC_SVE_64,      (0b011001) /* 0x19 - FEAT_SVE required */
#define ESR_ELX_EC_ERET,        (0b011010) /* 0x1A - EL2 only */
/* Unallocated 0b011011 (0x1B) */
#define ESR_ELX_EC_FPAC,        (0b011100) /* 0x1C - EL1 or above - FEAT_FPAC required */
#define ESR_ELX_EC_SME,         (0b011101) /* 0x1D */
/* Unallocated 0b011110 (0x1E)*/
#define ESR_ELX_EC_IMP_DEF,     (0b011111) /* 0x1F - EL3 only */
#define ESR_ELX_EC_IABT_LOW,    (0b100000) /* 0x20 */
#define ESR_ELX_EC_IABT_CUR,    (0b100001) /* 0x21 */
#define ESR_ELX_EC_PC_ALIGN,    (0b100010) /* 0x22 */
/* Unallocated 0b100011 (0x23) */
#define ESR_ELX_EC_DABT_LOW,    (0b100100) /* 0x24 */
#define ESR_ELX_EC_DABT_CUR,    (0b100101) /* 0x25 */
#define ESR_ELX_EC_SP_ALIGN,    (0b100110) /* 0x26 */
#define ESR_ELX_EC_MOPS,        (0b100111) /* 0x27 - FEAT_MOPS required */
#define ESR_ELX_EC_FP_32,       (0b101000) /* 0x28 */
/* Unallocated 0b101001 - 0b101011 (0x29 - 0x2B) */
#define ESR_ELX_EC_FP_64,       (0b101100) /* 0x2C */
/* Unallocated 0b101101 - 0b101110 (0x2D - 0x2E) */
#define ESR_ELX_EC_SERROR,      (0b101111) /* 0x2F */
#define ESR_ELx_EC_BREAKPT_LOW, (0b110000) /* 0x30 */
#define ESR_ELx_EC_BREAKPT_CUR, (0b110001) /* 0x31 */
#define ESR_ELx_EC_SW_STEP_LOW, (0b110010) /* 0x32 */
#define ESR_ELx_EC_SW_STEP_CUR, (0b110011) /* 0x33 */
#define ESR_ELx_EC_WATCHPT_LOW, (0b110100) /* 0x34 */
#define ESR_ELx_EC_WATCHPT_CUR, (0b110101) /* 0x35 */
/* Unallocated: 0b110110 - 0b110111 (0x36 - 0x37) */
#define ESR_ELx_EC_BKPT32,      (0b111000) /* 0x38 */
/* Unallocated: 0b1101001 (0x39) */
#define ESR_ELx_EC_VECTOR32,    (0b111010) /* 0x3A - EL2 only */
/* Unallocated: 0b111011 (0x3B) */
#define ESR_ELx_EC_BRK64,       (0b111100) /* 0x3C */
/* Unallocated: 0b111101 - 0b111111 (0x3D - 0x3F) */
#define ESR_ELx_EC_MAX,         (0b111111) /* 0x3F */

#endif /* ESR_H */
