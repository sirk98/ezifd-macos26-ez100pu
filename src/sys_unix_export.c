/*
 * macOS 26's linker keeps symbols marked INTERNAL local while leaving
 * cross-object references unresolved in a loadable IFD bundle.  Compile the
 * existing PCSC system helpers with default visibility so the bundle remains
 * self-contained when loaded by com.apple.ifdbundle.
 */

#include "misc.h"

#undef INTERNAL
#define INTERNAL

#include "sys_unix.c"
