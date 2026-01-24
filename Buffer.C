#include <stdint.h>
#include <string.h>

int buffer_write(uint8_t *buffer, size_t buffer_size,
                 size_t offset, const void *data, size_t data_len) {
    if (offset + data_len > buffer_size) {
        return -1;  // overflow
    }

    memcpy(buffer + offset, data, data_len);
    return 0;
}