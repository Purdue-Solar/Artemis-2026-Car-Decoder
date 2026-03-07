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

struct status_flags { /* Bit positions are logical fields, not memory layout */
  unsigned regen : 1; /* Bit 0: Regenerative braking active */
  unsigned cruise_down : 1;             /* Bit 1: Cruise control decrease */
  unsigned cruise_up : 1;               /* Bit 2: Cruise control increase */
  unsigned cruise : 1;                  /* Bit 3: Cruise control active */
  unsigned aux_over_voltage : 1;        /* Bit 4: Auxiliary over voltage */
  unsigned aux_under_voltage : 1;       /* Bit 5: Auxiliary under voltage */
  unsigned aux_over_current : 1;        /* Bit 6: Auxiliary over current */
  unsigned aux_current_warning : 1;     /* Bit 7: Auxiliary current warning */
  unsigned main_over_voltage : 1;       /* Bit 8: Main battery over voltage */
  unsigned main_under_voltage : 1;      /* Bit 9: Main battery under voltage */
  unsigned main_over_current_error : 1; /* Bit 10: Main over current error */
  unsigned main_current_warning : 1;    /* Bit 11: Main current warning */
  unsigned aux_condition : 4;           /* Bits 12-15: Auxiliary condition */
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
  struct status_flags oh_no_bits; /* Decoded status flags */
};

int read_message_from_file(FILE *file, struct message *msg);
float convert_to_b_float(uint16_t data);
void parse_status_flags(uint16_t bits, struct status_flags *flags);
void print_bool_array(FILE *file, const uint8_t *values, size_t length,
                      const char *delimiter);
int main(int argc, char *argv[]);

#endif /* DECODER_H */
