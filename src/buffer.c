#include "buffer.h"
#include <string.h>

int buffer_write(Buffer *buffer, const uint8_t *data, size_t data_len) {
    if (!buffer || !buffer->data || !data) {
        return -1;
    }

    for (size_t i = 0; i < data_len; i++) {
        buffer->data[buffer->write_pos] = data[i];
        buffer->write_pos = (buffer->write_pos + 1) % buffer->size;

        if (buffer->count == buffer->size) {
            buffer->read_pos = (buffer->read_pos + 1) % buffer->size;
        } else {
            buffer->count++;
        }
    }

    return 0;
}

int buffer_read(Buffer *buffer, uint8_t *data, size_t data_len) {
    if (!buffer || !buffer->data || !data) {
        return -1;
    }

    if (data_len > buffer->count) {
        return -1;
    }

    for (size_t i = 0; i < data_len; i++) {
        data[i] = buffer->data[buffer->read_pos];
        buffer->read_pos = (buffer->read_pos + 1) % buffer->size;
        buffer->count--;
    }

    return 0;
}
