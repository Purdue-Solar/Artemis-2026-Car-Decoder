#include "decoder.h"

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
  if (argc != 1) {
    fprintf(stderr, "Usage: %s\n", argv[0]);
    return 1;
  }

  struct message message_data = {0};
  while (read_message_from_file(stdin, &message_data) == 0) {
    fprintf(stdout, "%ld,%u,%u,%u,%u,%u,%f,%f,%f,%f,", message_data.time_stamp,
            message_data.battery_temp, message_data.SOC, message_data.limit,
            message_data.diag_one, message_data.diag_two,
            message_data.motor_curr, message_data.motor_vel, message_data.sink,
            message_data.temp);
    print_bool_flags(stdout, &message_data.oh_no_bits, ",");
    fprintf(stdout, ",%u\n", message_data.oh_no_bits.aux_condition);
  }
  return 0;
}
