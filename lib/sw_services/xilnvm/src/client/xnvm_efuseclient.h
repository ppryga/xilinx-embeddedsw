/******************************************************************************
* Copyright (c) 2021 Xilinx, Inc.  All rights reserved.
* SPDX-License-Identifier: MIT
*******************************************************************************/

/*****************************************************************************/
/**
*
* @file xnvm_efuseclient.h
* @addtogroup xnvm_efuse_client_apis XilNvm eFUSE Versal Client APIs
* @{
* @cond xnvm_internal
* This file Contains the client function prototypes, defines and macros for
* the eFUSE programming and read.
*
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who  Date     Changes
* ----- ---- -------- -------------------------------------------------------
* 1.0   kal  07/29/21 Initial release
*       kpt  08/27/21 Added client API's to support puf helper data efuse
*                     programming
*       kpt  03/16/22 Removed IPI related code and added mailbox support
*
* </pre>
*
* @note
*
******************************************************************************/

#ifndef XNVM_EFUSECLIENT_H
#define XNVM_EFUSECLIENT_H

#ifdef __cplusplus
extern "C" {
#endif

/***************************** Include Files *********************************/
#include "xil_types.h"
#include "xnvm_defs.h"
#include "xnvm_mailbox.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/
#define XNVM_WORD_LEN		(4U)

/************************** Function Prototypes ******************************/
int XNvm_EfuseWrite(XNvm_ClientInstance *InstancePtr, const u64 DataAddr);
int XNvm_EfuseWriteIVs(XNvm_ClientInstance *InstancePtr, const u64 IvAddr, const u32 EnvDisFlag);
int XNvm_EfuseRevokePpk(XNvm_ClientInstance *InstancePtr, const XNvm_PpkType PpkRevoke, const u32 EnvDisFlag);
int XNvm_EfuseWriteRevocationId(XNvm_ClientInstance *InstancePtr, const u32 RevokeId, const u32 EnvDisFlag);
int XNvm_EfuseWriteUserFuses(XNvm_ClientInstance *InstancePtr, const u64 UserFuseAddr, const u32 EnvDisFlag);
int XNvm_EfuseReadIv(XNvm_ClientInstance *InstancePtr, const u64 IvAddr, const XNvm_IvType IvType);
int XNvm_EfuseReadRevocationId(XNvm_ClientInstance *InstancePtr, const u64 RevokeIdAddr, const XNvm_RevocationId RevokeIdNum);
int XNvm_EfuseReadUserFuses(XNvm_ClientInstance *InstancePtr, const u64 UserFuseAddr);
int XNvm_EfuseReadMiscCtrlBits(XNvm_ClientInstance *InstancePtr, const u64 MiscCtrlBits);
int XNvm_EfuseReadSecCtrlBits(XNvm_ClientInstance *InstancePtr, const u64 SecCtrlBits);
int XNvm_EfuseReadSecMisc1Bits(XNvm_ClientInstance *InstancePtr, const u64 SecMisc1Bits);
int XNvm_EfuseReadBootEnvCtrlBits(XNvm_ClientInstance *InstancePtr, const u64 BootEnvCtrlBits);
int XNvm_EfuseReadPufSecCtrlBits(XNvm_ClientInstance *InstancePtr, const u64 PufSecCtrlBits);
int XNvm_EfuseReadOffchipRevokeId(XNvm_ClientInstance *InstancePtr, const u64 OffChidIdAddr, const XNvm_OffchipId OffChipIdNum);
int XNvm_EfuseReadPpkHash(XNvm_ClientInstance *InstancePtr, const u64 PpkHashAddr, const XNvm_PpkType PpkHashType);
int XNvm_EfuseReadDecOnly(XNvm_ClientInstance *InstancePtr, const u64 DecOnlyAddr);
int XNvm_EfuseReadDna(XNvm_ClientInstance *InstancePtr, const u64 DnaAddr);
#ifdef XNVM_ACCESS_PUF_USER_DATA
int XNvm_EfuseWritePufAsUserFuses(XNvm_ClientInstance *InstancePtr, u64 PufUserFuseAddr);
int XNvm_EfuseReadPufAsUserFuses(XNvm_ClientInstance *InstancePtr, const u64 PufUserFuseAddr);
#else
int XNvm_EfuseWritePuf(XNvm_ClientInstance *InstancePtr, const u64 PufHdAddr);
int XNvm_EfuseReadPuf(XNvm_ClientInstance *InstancePtr, const u64 PufHdAddr);
#endif

/************************** Variable Definitions *****************************/

#ifdef __cplusplus
}
#endif

#endif  /* XNVM_EFUSECLIENT_H */
