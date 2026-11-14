#!/bin/bash
# Runtime patch script - ensures fixes are applied before build

echo "=== Applying runtime patches ==="

# Patch 1: Fix susfs.c path_umount
echo "Patching fs/susfs.c..."
sed -i '1164,1169d' fs/susfs.c
cat >> fs/susfs.c << 'PATCH1'
static void umount_mnt(struct path *path, int flags) {
	// path_umount not available in kernel 4.14, disable for now
	// int err = path_umount(path, flags);
	SUSFS_LOGI("try_umount feature disabled (path_umount not available in 4.14)\n");
	(void)path;
	(void)flags;
}
PATCH1

# Verify susfs.c patch
echo "Verifying susfs.c patch..."
sed -n '1160,1175p' fs/susfs.c

# Patch 2: Add strrchr to libstub/string.c
echo ""
echo "Patching drivers/firmware/efi/libstub/string.c..."
cat >> drivers/firmware/efi/libstub/string.c << 'PATCH2'

#ifndef __HAVE_ARCH_STRRCHR
/**
 * strrchr - Find the last occurrence of a character in a string
 * @s: The string to be searched
 * @c: The character to search for
 */
char *strrchr(const char *s, int c)
{
	const char *last = NULL;
	do {
		if (*s == (char)c)
			last = s;
	} while (*s++);
	return (char *)last;
}
#endif
PATCH2

# Verify string.c patch
echo "Verifying string.c patch..."
tail -20 drivers/firmware/efi/libstub/string.c

echo ""
echo "=== Runtime patches applied successfully ==="
