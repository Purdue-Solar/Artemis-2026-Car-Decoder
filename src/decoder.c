/* Authors: Nanson Chen, Daniel Xu */
/* Created on: 1/24/2026 */
#include "decoder.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

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
 * Returns: 0 for success, 1 for any error or end of file
 */
int read_message_from_file(FILE *file, struct message *msg) {
  if (file == NULL) {
    fprintf(stderr, "Error: file is NULL\n");
    return 1;
  }

  unsigned char buffer[MESSAGE_SIZE_IN_BYTES];

  size_t bytes_read = fread(buffer, 1, MESSAGE_SIZE_IN_BYTES, file);

  if (bytes_read != MESSAGE_SIZE_IN_BYTES) {
    /* Only print error for partial reads, not clean EOF */
    if (bytes_read > 0) {
      fprintf(stderr,
              "Error: Incomplete message, expected 19 bytes, read %zu\n",
              bytes_read);
    }
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

  msg->motor_curr = convert_to_b_float(((uint16_t)buffer[offset]) |
                                       ((uint16_t)buffer[offset + 1] << 8));
  offset += 2;

  msg->motor_vel = convert_to_b_float(((uint16_t)buffer[offset]) |
                                      ((uint16_t)buffer[offset + 1] << 8));
  offset += 2;

  msg->sink = convert_to_b_float(((uint16_t)buffer[offset]) |
                                 ((uint16_t)buffer[offset + 1] << 8));
  offset += 2;

  msg->temp = convert_to_b_float(((uint16_t)buffer[offset]) |
                                 ((uint16_t)buffer[offset + 1] << 8));
  offset += 2;

  uint16_t status_bits =
      ((uint16_t)buffer[offset]) | ((uint16_t)buffer[offset + 1] << 8);
  parse_status_flags(status_bits, &msg->oh_no_bits);
  offset += 2;

  return 0;
} /* read_message_from_file() */

/*
 * Function Name: convert_to_b_float
 * Converts a 16 bit bfloat16 value into a 32 bit float
 *
 * Parameters:
 *   data - is the 16 bit bfloat16 value to convert
 *
 * Returns: the 32 bit float representation
 */
float convert_to_b_float(uint16_t data) {
  uint32_t bits = ((uint32_t)data) << 16;
  float result;
  memcpy(&result, &bits, sizeof(float));
  return result;
} /* convert_to_b_float() */

/*
 * Function Name: parse_status_flags
 * Parses a 16-bit status field into individual flag components
 *
 * Parameters:
 *   bits - the 16-bit status word to parse
 *   flags - pointer to status_flags struct to populate
 *
 * Returns: void
 */
void parse_status_flags(uint16_t bits, struct status_flags *flags) {
  flags->regen = (bits >> 0) & 0x01;
  flags->cruise_down = (bits >> 1) & 0x01;
  flags->cruise_up = (bits >> 2) & 0x01;
  flags->cruise = (bits >> 3) & 0x01;
  flags->aux_over_voltage = (bits >> 4) & 0x01;
  flags->aux_under_voltage = (bits >> 5) & 0x01;
  flags->aux_over_current = (bits >> 6) & 0x01;
  flags->aux_current_warning = (bits >> 7) & 0x01;
  flags->main_over_voltage = (bits >> 8) & 0x01;
  flags->main_under_voltage = (bits >> 9) & 0x01;
  flags->main_over_current_error = (bits >> 10) & 0x01;
  flags->main_current_warning = (bits >> 11) & 0x01;
  flags->aux_condition = (bits >> 12) & 0x0F;
} /* parse_status_flags() */

/*
 * Function Name: print_bool_flags
 * Prints status flag fields as boolean strings to a file
 *
 * Parameters:
 *   file - the file to write to
 *   flags - pointer to status_flags struct
 *   delimiter - string to use as separator between values
 *
 * Returns: void
 */
void print_bool_flags(FILE *file, const struct status_flags *flags,
                      const char *delimiter) {
  if ((file == NULL) || (flags == NULL) || (delimiter == NULL)) {
    return;
  }

  const unsigned values[12] = {
      flags->regen,
      flags->cruise_down,
      flags->cruise_up,
      flags->cruise,
      flags->aux_over_voltage,
      flags->aux_under_voltage,
      flags->aux_over_current,
      flags->aux_current_warning,
      flags->main_over_voltage,
      flags->main_under_voltage,
      flags->main_over_current_error,
      flags->main_current_warning,
  };

  for (size_t i = 0; i < 12; i++) {
    fprintf(file, "%s", values[i] ? "True" : "False");
    if (i < 11) {
      fprintf(file, "%s", delimiter);
    }
  }
} /* print_bool_flags() */
