#ifndef DECODER_H
#define DECODER_H

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

int read_message_from_file(FILE *file, struct message *msg);
int main(int argc, char *argv[]);

#endif /* DECODER_H */
