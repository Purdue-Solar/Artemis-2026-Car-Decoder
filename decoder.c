/* Authors: Nanson Chen, Daniel Xu */
/* Created on: 1/24/2026 */
#include "decoder.h"

#include <stdint.h>
#include <stdio.h>

/*
 * Function Name: read_message_from_file
 * Reads a struct message from a binary file (19 bytes).
 * Assumes message is pure data (no padding, no message header...)
 * Overwrites the contents of the message pointer with deserialized data.
 * Assumes big-endian byte order
 * 
 * Parameters:
 *   filepath - path to the binary file
 *   msg - pointer to struct message to populate
 * 
 * Returns: 0 for success, 1 for any error
 */
int read_message_from_file(const char *filepath, struct message *msg) {
    FILE *file = fopen(filepath, "rb");
    if (file == NULL) {
        fprintf(stderr, "Error: Could not open file %s\n", filepath);
        return 1;
    }
    
    unsigned char buffer[19];
    
    size_t bytes_read = fread(buffer, 1, 19, file);
    fclose(file);
    
    if (bytes_read != 19) {
        fprintf(stderr, "Error: Expected 19 bytes, read %zu\n", bytes_read);
        return 1;
    }
    
    int offset = 0;
    
    // Deserialize time_stamp (4 bytes, big-endian)
    msg->time_stamp = ((uint32_t)buffer[offset] << 24) |
                      ((uint32_t)buffer[offset + 1] << 16) |
                      ((uint32_t)buffer[offset + 2] << 8) |
                      ((uint32_t)buffer[offset + 3]);
    offset += 4;
    
    // Deserialize battery_temp (1 byte)
    msg->battery_temp = buffer[offset++];
    
    // Deserialize SOC (1 byte)
    msg->SOC = buffer[offset++];
    
    // Deserialize limit (1 byte)
    msg->limit = buffer[offset++];
    
    // Deserialize diag_one (1 byte)
    msg->diag_one = buffer[offset++];
    
    // Deserialize diag_two (1 byte)
    msg->diag_two = buffer[offset++];
    
    // Deserialize motor_curr (2 bytes, big-endian)
    msg->motor_curr = ((uint16_t)buffer[offset] << 8) | ((uint16_t)buffer[offset + 1]);
    offset += 2;
    
    // Deserialize motor_vel (2 bytes, big-endian)
    msg->motor_vel = ((uint16_t)buffer[offset] << 8) | ((uint16_t)buffer[offset + 1]);
    offset += 2;
    
    // Deserialize sink (2 bytes, big-endian)
    msg->sink = ((uint16_t)buffer[offset] << 8) | ((uint16_t)buffer[offset + 1]);
    offset += 2;
    
    // Deserialize temp (2 bytes, big-endian)
    msg->temp = ((uint16_t)buffer[offset] << 8) | ((uint16_t)buffer[offset + 1]);
    offset += 2;
    
    // Deserialize oh_no_bits (2 bytes, big-endian)
    msg->oh_no_bits = ((uint16_t)buffer[offset] << 8) | ((uint16_t)buffer[offset + 1]);
    offset += 2;

    return 0;
}

/*
 * Function Name: main
 * The entry point of the decoder.
 * 
 * Returns: An exit code
 */
int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Expected 1 argument, gotten %d\n", (argc - 1));
        printf("Arguments read:\n");
        for (int i = 1; i < argc; i++) {
            printf("%s", argv[i]);
            if (i != argc - 1) {
                printf(", ");
            }
        }
        printf("\n");
        printf("Usage: <executable> <output_path>\n");
        return 1;
    }

    printf("This code is chopped\n");
    return 0;
}
