/* Authors: Nanson Chen, Daniel Xu */
/* Created on: 1/24/2026 */
#include "decoder.h"

#include <stdint.h>
#include <stdio.h>

struct message {
    uint32_t time_stamp;
    uint8_t battery_temp;
    uint8_t SOC;
    uint8_t limit;
    uint8_t diag_one;
    uint8_t diag_two;
    uint16_t motor_curr;
    uint16_t motor_vel;
    uint16_t sink;
    uint16_t temp;
    uint16_t oh_no_bits;
};

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
