#include "decoder.h"

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Usage: %s <input_bin> <output_csv>\n", argv[0]);
    return 1;
  }

  FILE *in_file = fopen(argv[1], "rb");
  if (in_file == NULL) {
    fprintf(stderr, "Failed to open input: %s\n", argv[1]);
    return 1;
  }

  FILE *out_file = fopen(argv[2], "w");
  if (out_file == NULL) {
    fprintf(stderr, "Failed to open output: %s\n", argv[2]);
    fclose(in_file);
    return 1;
  }

  struct message message_data = {0};
  while (read_message_from_file(in_file, &message_data) == 0) {
    fprintf(out_file, "%ld,%u,%u,%u,%u,%u,%f,%f,%f,%f,",
            message_data.time_stamp, message_data.battery_temp,
            message_data.SOC, message_data.limit, message_data.diag_one,
            message_data.diag_two, message_data.motor_curr,
            message_data.motor_vel, message_data.sink, message_data.temp);
    struct status_flags flags = {0};
    parse_status_flags(message_data.oh_no_bits, &flags);
    print_bool_array(out_file, &flags.regen, 12, ",");
    fprintf(out_file, ",%u\n", flags.aux_condition);
  }

  fclose(in_file);
  fclose(out_file);
  return 0;
}
