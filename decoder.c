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

  msg->oh_no_bits =
      ((uint16_t)buffer[offset]) | ((uint16_t)buffer[offset + 1] << 8);
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
 * Function Name: print_bool_array
 * Prints an array of uint8_t values as boolean strings to a file
 *
 * Parameters:
 *   file - the file to write to
 *   values - pointer to array of uint8_t values (treated as booleans)
 *   length - number of values to print
 *   delimiter - string to use as separator between values
 *
 * Returns: void
 */
void print_bool_array(FILE *file, const uint8_t *values, size_t length,
                      const char *delimiter) {
  for (size_t i = 0; i < length; i++) {
    fprintf(file, "%s", values[i] ? "True" : "False");
    if (i < length - 1) {
      fprintf(file, "%s", delimiter);
    }
  }
} /* print_bool_array() */

/*
 * Function Name: main
 * The entry point of the decoder.
 *
 * Returns: An exit code
 */
int main(int argc, char *argv[]) {
  FILE *in_file = NULL;
  FILE *out_file = NULL;
  int return_code = 0;
  if ((argc != 2) || (argc != 3)) {
    fprintf(stderr, "Expected 2 or less arguments, gotten %d\n", (argc - 1));
    fprintf(stderr, "Arguments read:\n");
    for (int i = 1; i < argc; i++) {
      fprintf(stderr, "%s", argv[i]);
      if (i != argc - 1) {
        printf(", ");
      }
    }
    fprintf(stderr, "\n");
    fprintf(stderr, "Usage: <executable> <output_path> or\n");
    fprintf(stderr, "Usage: <executable> <output_path> <input_path>\n");
    return_code = BAD_NUM_ARGUMENTS;
    goto cleanup;
  }
  if (argc == 3) {
    in_file = fopen(argv[2], "rb");
    if (in_file == NULL) {
      printf("Input file cannot be opened");
    }
    return_code = FILE_READ_ERR;
    goto cleanup;
  }
  else {
    in_file = stdin;
  }
  out_file = fopen(argv[1], "w");
  if (out_file == NULL) {
    printf("Destination file cannot be written to (%s)", argv[1]);
    return_code = FILE_WRITE_ERR;
    goto cleanup;
  }

  /* Write actual code here */
  struct message message_data = {0};
  int message_code = read_message_from_file(in_file, &message_data);
  while (message_code == 0) {
    fprintf(out_file, "%ld,%u,%u,%u,%u,%u,%f,%f,%f,%f,",
            message_data.time_stamp, message_data.battery_temp,
            message_data.SOC, message_data.limit, message_data.diag_one,
            message_data.diag_two, message_data.motor_curr,
            message_data.motor_vel, message_data.sink, message_data.temp);
    struct status_flags flags = {0};
    parse_status_flags(message_data.oh_no_bits, &flags);
    print_bool_array(out_file, &flags.regen, 12, ",");
    fprintf(out_file, ",%u\n", flags.aux_condition);
    message_code = read_message_from_file(in_file, &message_data);
  }

cleanup:
  if (in_file != NULL) {
    fclose(in_file);
    in_file = NULL;
  }
  if (out_file != NULL) {
    fclose(out_file);
    out_file = NULL;
  }
  return return_code;
} /* main() */
