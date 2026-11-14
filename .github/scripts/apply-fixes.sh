#!/bin/bash
# Runtime patch script - ensures fixes are applied before build

echo "=== Applying runtime patches ==="

# Patch 1: Fix susfs.c path_umount
echo "Patching fs/susfs.c..."
# Find the exact line numbers for umount_mnt function
START_LINE=$(grep -n "^static void umount_mnt" fs/susfs.c | cut -d: -f1)
if [ -n "$START_LINE" ]; then
  # Find the closing brace (next standalone })
  END_LINE=$(tail -n +$START_LINE fs/susfs.c | grep -n "^}" | head -1 | cut -d: -f1)
  END_LINE=$((START_LINE + END_LINE - 1))
  
  echo "Replacing umount_mnt function (lines $START_LINE-$END_LINE)..."
  
  # Create a new version of the file
  head -n $((START_LINE - 1)) fs/susfs.c > fs/susfs.c.tmp
  
  # Add the patched function
  cat >> fs/susfs.c.tmp << 'PATCH1'
static void umount_mnt(struct path *path, int flags) {
	// path_umount not available in kernel 4.14, disable for now
	// int err = path_umount(path, flags);
	SUSFS_LOGI("try_umount feature disabled (path_umount not available in 4.14)\n");
	(void)path;
	(void)flags;
}
PATCH1
  
  # Add the rest of the file
  tail -n +$((END_LINE + 1)) fs/susfs.c >> fs/susfs.c.tmp
  
  # Replace original file
  mv fs/susfs.c.tmp fs/susfs.c
  
  echo "Patch applied successfully"
else
  echo "WARNING: umount_mnt function not found, might already be patched"
fi

# Force recompile by touching file
touch fs/susfs.c
echo "Touched fs/susfs.c to force recompile"

# Verify susfs.c patch
echo "Verifying susfs.c patch..."
sed -n '1160,1175p' fs/susfs.c

# Patch 2: Add strrchr to libstub/string.c
echo ""
echo "Patching drivers/firmware/efi/libstub/string.c..."

# Check if strrchr already exists
if ! grep -q "__HAVE_ARCH_STRRCHR" drivers/firmware/efi/libstub/string.c; then
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
  echo "strrchr added"
else
  echo "strrchr already exists, skipping"
fi

# Force recompile by touching file
touch drivers/firmware/efi/libstub/string.c
echo "Touched string.c to force recompile"

# Verify string.c patch
echo "Verifying string.c patch..."
tail -20 drivers/firmware/efi/libstub/string.c

# Force clean to remove any cached objects
echo ""
echo "Removing any cached object files..."
rm -f fs/susfs.o fs/.susfs.o.cmd out/fs/susfs.o out/fs/.susfs.o.cmd
rm -f drivers/firmware/efi/libstub/*.o
rm -f drivers/firmware/efi/libstub/.*.o.cmd
rm -f out/drivers/firmware/efi/libstub/*.o
rm -f out/drivers/firmware/efi/libstub/.*.o.cmd
echo "Cached objects removed"

echo ""
echo "=== Runtime patches applied successfully ==="
