/*
 * Freestanding byte-wise memory primitives for the RV32 boot image.
 * The link is performed with -nostdlib, but compiler-generated code may still
 * reference the standard memcpy/memset ABI.  These routines deliberately use
 * byte accesses and must remain available before any board peripheral setup.
 */
typedef unsigned int size_t;

void *memcpy(void *destination, const void *source, size_t byte_count) {
    unsigned char *destination_bytes = destination;
    const unsigned char *source_bytes = source;
    for (size_t index = 0; index < byte_count; ++index)
        destination_bytes[index] = source_bytes[index];
    return destination;
}

void *memset(void *destination, int value, size_t byte_count) {
    unsigned char *destination_bytes = destination;
    for (size_t index = 0; index < byte_count; ++index)
        destination_bytes[index] = (unsigned char)value;
    return destination;
}
