#ifndef DECODER_H
#define DECODER_H

#include <stdint.h>
#include <stdio.h>
#include <time.h>

/* Error codes */

#define BAD_NUM_ARGUMENTS (-1)
#define FILE_READ_ERR (-2)
#define FILE_WRITE_ERR (-3)

/* Program Constants */

#define MESSAGE_SIZE_IN_BYTES (19)

struct message {
  time_t time_stamp;    /* 32 bit long */
  uint8_t battery_temp; /* Unsigned integer in Celsius */
  uint8_t SOC;          /* Unsigned integer (0-100% charge of battery) */
  uint8_t limit;        /* Unsigned integer */
  uint8_t diag_one;     /* Unsigned integer */
  uint8_t diag_two;     /* Unsigned integer */
  float motor_curr;     /* B-float (Motor current draw) */
  float motor_vel;      /* B-float */
  float sink;           /* B-float (Heat sink temperature in Celsius) */
  float temp;           /* B-float (Unknown temperature in Celsius) */
  uint16_t oh_no_bits;  /* 2 bytes for "boolean" data */
};

int read_message_from_file(FILE *file, struct message *msg);
float convert_to_b_float(uint16_t data);
int main(int argc, char *argv[]);

#endif /* DECODER_H */
