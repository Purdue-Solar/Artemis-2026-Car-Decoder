/* main.c */
#include <stdio.h>
#include "buffer.h"
#include "can_decode.h"

#define BUFFER_SIZE_BYTES (8u * 1024u * 1024u)  // 8 MB

int main(void) {
    Buffer buf;
    if (buffer_init(&buf, BUFFER_SIZE_BYTES) != 0) {
        fprintf(stderr, "Failed to init buffer\n");
        return 1;
    }

    uint8_t incoming[2] = { 0xA5, 0x96 };
    buffer_write(&buf, incoming, 2);

    Row11Flags flags;
    if (decode_row11_from_buffer(&buf, &flags) != 0) {
        fprintf(stderr, "Not enough data to decode\n");
        buffer_free(&buf);
        return 1;
    }

    print_row11(&flags);

    buffer_free(&buf);
    return 0;
}
