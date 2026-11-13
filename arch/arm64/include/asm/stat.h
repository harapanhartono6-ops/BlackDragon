/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __ASM_STAT_H
#define __ASM_STAT_H

#include <uapi/asm/stat.h>

#ifdef CONFIG_COMPAT

#include <asm/compat.h>

/*
 * struct stat64 is defined in asm-generic/stat.h for arm64
 * (__BITS_PER_LONG defaults to 32, so __BITS_PER_LONG != 64).
 * No local redefinition needed.
 */

#endif
#endif
