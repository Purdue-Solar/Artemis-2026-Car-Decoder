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

struct status_flags {              /* ORDER IS IMPORTANT */
  uint8_t regen;                   /* Bit 0: Regenerative braking active */
  uint8_t cruise_down;             /* Bit 1: Cruise control decrease */
  uint8_t cruise_up;               /* Bit 2: Cruise control increase */
  uint8_t cruise;                  /* Bit 3: Cruise control active */
  uint8_t aux_over_voltage;        /* Bit 4: Auxiliary over voltage */
  uint8_t aux_under_voltage;       /* Bit 5: Auxiliary under voltage */
  uint8_t aux_over_current;        /* Bit 6: Auxiliary over current */
  uint8_t aux_current_warning;     /* Bit 7: Auxiliary current warning */
  uint8_t main_over_voltage;       /* Bit 8: Main battery over voltage */
  uint8_t main_under_voltage;      /* Bit 9: Main battery under voltage */
  uint8_t main_over_current_error; /* Bit 10: Main over current error */
  uint8_t main_current_warning;    /* Bit 11: Main current warning */
  uint8_t aux_condition; /* Bits 12-15: Auxiliary condition (4 bits) */
};

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
void parse_status_flags(uint16_t bits, struct status_flags *flags);
void print_bool_array(FILE *file, const uint8_t *values, size_t length,
                      const char *delimiter);
int main(int argc, char *argv[]);

#endif /* DECODER_H */
