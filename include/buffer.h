#ifndef BUFFER_H
#define BUFFER_H

#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint8_t *data;
    size_t size;
    size_t write_pos;
    size_t read_pos;
    size_t count;   // number of bytes currently in buffer
} Buffer;

/**
 * Write bytes into the circular buffer.
 * Overwrites oldest data if buffer is full.
 *
 * @return 0 on success, -1 on error
 */
int buffer_write(Buffer *buffer, const uint8_t *data, size_t data_len);

/**
 * Read bytes from the circular buffer.
 *
 * @return 0 on success, -1 on error
 */
int buffer_read(Buffer *buffer, uint8_t *data, size_t data_len);

#endif // BUFFER_H
