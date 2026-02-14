#ifndef DECODER_H
#define DECODER_H

#include <stdint.h>
#include <stdio.h>
#include <time.h>

struct message {
    time_t time_stamp;
    uint8_t battery_temp;
    uint8_t SOC;
    uint8_t limit;
    uint8_t diag_one;
    uint8_t diag_two;
    float motor_curr;
    float motor_vel;
    float sink;
    float temp;
    uint16_t oh_no_bits;
};

int read_message_from_file(FILE *file, struct message *msg);
float convert_to_b_float(uint16_t data);
int main(int argc, char *argv[]);

#endif /* DECODER_H */
