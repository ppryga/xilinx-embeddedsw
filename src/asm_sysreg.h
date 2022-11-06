/******************************************************************************
* Copyright (c) 2022 Piotr Pryga - All rights reserved.
*
* Author: Piotr Pryga <pryga.piotr@outlook.com>
* SPDX-License-Identifier: MIT
******************************************************************************/
/*****************************************************************************/
/**
* @file asm_sysreg.h
*
* This file contains code that helps handling access to aarch64 system
* registers.
******************************************************************************/

#ifndef ARM_SYSREG_H
/** @brief Read system register with provided name and "return" its value.
 *
 * The macro may be used e.g. in an assignment expressions e.g.
 * uint64_t esr_value = SYSTEG_READ(est_el1);
 */
#define SYSREG_READ(reg_name) ({						\
	u64 reg_value;								\
	asm volatile("mrs %0, " STRINGIFY(reg_name) : "=r" (reg_value));	\
	reg_value;								\
})

#endif /* ARM_SYSREG_H */
