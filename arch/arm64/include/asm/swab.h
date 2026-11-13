/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __ASM_SWAB_H
#define __ASM_SWAB_H

static inline unsigned int __swab32(unsigned int x)
{
	return ((x >> 24) & 0xff) |
	       ((x >> 8) & 0xff00) |
	       ((x << 8) & 0xff0000) |
	       ((x << 24) & 0xff000000);
}

static inline unsigned short __swab16(unsigned short x)
{
	return ((x >> 8) & 0xff) | ((x << 8) & 0xff00);
}

#endif /* __ASM_SWAB_H */
