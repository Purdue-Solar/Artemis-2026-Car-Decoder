/* Authors: Nanson Chen, Daniel Xu */
/* Created on: 1/24/2026 */
#include "decoder.h"

#include <stdint.h>
#include <stdio.h>

/*
 * Function Name: read_message_from_file
 * Reads a struct message from a binary file (19 bytes).
 * Overwrites the contents of the message pointer with deserialized data.
 * Assumes little-endian byte order
 * 
 * Parameters:
 *   file - the file to read from (an actual file or a standard stream)
 *   msg - pointer to struct message to populate
 * 
 * Returns: 0 for success, 1 for any error
 */
int read_message_from_file(FILE *file, struct message *msg) {
    if (file == NULL) {
        fprintf(stderr, "Error: file is NULL\n");
        return 1;
    }
    
    unsigned char buffer[19];
    
    size_t bytes_read = fread(buffer, 1, 19, file);
    
    if (bytes_read != 19) {
        fprintf(stderr, "Error: Expected 19 bytes, read %zu\n", bytes_read);
        return 1;
    }
    
    int offset = 0;

    msg->time_stamp = ((uint32_t)buffer[offset]) |
                      ((uint32_t)buffer[offset + 1] << 8) |
                      ((uint32_t)buffer[offset + 2] << 16) |
                      ((uint32_t)buffer[offset + 3] << 24);
    offset += 4;

    msg->battery_temp = buffer[offset++];

    msg->SOC = buffer[offset++];

    msg->limit = buffer[offset++];

    msg->diag_one = buffer[offset++];

    msg->diag_two = buffer[offset++];

    msg->motor_curr = convert_to_b_float(((uint16_t)buffer[offset]) | ((uint16_t)buffer[offset + 1] << 8));
    offset += 2;

    msg->motor_vel = convert_to_b_float(((uint16_t)buffer[offset]) | ((uint16_t)buffer[offset + 1] << 8));
    offset += 2;

    msg->sink = convert_to_b_float(((uint16_t)buffer[offset]) | ((uint16_t)buffer[offset + 1] << 8));
    offset += 2;

    msg->temp = convert_to_b_float(((uint16_t)buffer[offset]) | ((uint16_t)buffer[offset + 1] << 8));
    offset += 2;

    msg->oh_no_bits = ((uint16_t)buffer[offset]) | ((uint16_t)buffer[offset + 1] << 8);
    offset += 2;

    return 0;
}

/* 
 * Function Name: convert_to_b_float
 * Converts a 16 bit integer into a b float
 * 
 * Parameters:
 *   data - is the 16 bit integer to convert
 * 
 * Returns: the b float
 */
float convert_to_b_float(uint16_t data) {
    uint32_t upcast_data = data;
    upcast_data << 16;
    return ((float)upcast_data);
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

    FILE *out_file = fopen(argv[1], "a");
    if (out_file == NULL) {
        printf("Destination file cannot be written to (%s)", argv[1]);
        return 1;
    }

    /* Write actual code here */

    fclose(out_file);
    out_file = NULL;
    return 0;
}
