#ifndef BUFFER_H
#define BUFFER_H

#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint8_t *data;
    size_t size;
    size_t write_pos;
    size_t read_pos;
    size_t count;
} Buffer;

int  buffer_init(Buffer *buffer, size_t size_bytes);
void buffer_free(Buffer *buffer);

int buffer_write(Buffer *buffer, const uint8_t *data, size_t data_len);
int buffer_read(Buffer *buffer, uint8_t *data, size_t data_len);

#endif
