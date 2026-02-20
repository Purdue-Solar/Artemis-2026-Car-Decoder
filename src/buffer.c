/* Authors: Daniel Xu */

#include "buffer.h"
#include <stdlib.h>

int buffer_init(Buffer *buffer, size_t size_bytes) {
    if (!buffer || size_bytes == 0) return -1;

    buffer->data = (uint8_t*)malloc(size_bytes);
    if (!buffer->data) return -2;

    buffer->size = size_bytes;
    buffer->write_pos = 0;
    buffer->read_pos  = 0;
    buffer->count     = 0;
    return 0;
}

void buffer_free(Buffer *buffer) {
    if (!buffer) return;
    free(buffer->data);
    buffer->data = NULL;
    buffer->size = 0;
    buffer->write_pos = 0;
    buffer->read_pos  = 0;
    buffer->count     = 0;
}
