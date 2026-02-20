/*
* Implementation of a simple circular buffer in, no need for the extra RAM usage.
*/

/*#include <stdint.h>
#include <string.h>

typedef struct {
    uint8_t *data;
    size_t size;
    size_t write_pos;
    size_t read_pos;
    size_t count;  // number of bytes currently in buffer
} Buffer;

int buffer_write(Buffer *buffer, const uint8_t *data, size_t data_len) {
    if (!buffer || !buffer->data || !data) {
        return -1;  // null pointer
    }
    
    for (size_t i = 0; i < data_len; i++) {
        buffer->data[buffer->write_pos] = data[i];
        buffer->write_pos = (buffer->write_pos + 1) % buffer->size;
        
        // If buffer is full, advance read position (overwrite oldest data)
        if (buffer->count == buffer->size) {
            buffer->read_pos = (buffer->read_pos + 1) % buffer->size;
        } else {
            buffer->count++;
        }
    }
    
    return 0;  // success
}

int buffer_read(Buffer *buffer, uint8_t *data, size_t data_len) {
    if (!buffer || !buffer->data || !data) {
        return -1;  // null pointer
    }
    
    if (data_len > buffer->count) {
        return -1;  // not enough data in buffer
    }
    
    for (size_t i = 0; i < data_len; i++) {
        data[i] = buffer->data[buffer->read_pos];
        buffer->read_pos = (buffer->read_pos + 1) % buffer->size;
        buffer->count--;
    }
    
    return 0;  // success
}

*/