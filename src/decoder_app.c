/* Authors: Nanson Chen, Daniel Daniel Xu */
/* Created on: 1/24/2026 */
/* Decoder application entry point - extracted from decoder.c */
#include "decoder.h"
#include "message_queue.h"

#include <stdio.h>
#include <stdlib.h>

/*
 * Function Name: main
 * The entry point of the decoder application.
 *
 * Returns: An exit code
 */

int main(int argc, char *argv[]) {
  FILE *in_file = NULL;
  FILE *out_file = NULL;
  struct message_queue queue = {0};
  int return_code = 0;
  if ((argc < 1) || (argc > 3)) {
    fprintf(stderr, "Expected 0 to 2 arguments, got %d\n", (argc - 1));
    fprintf(stderr, "Arguments read:\n");
    for (int i = 1; i < argc; i++) {
      fprintf(stderr, "%s", argv[i]);
      if (i != argc - 1) {
        printf(", ");
      }
    }
    fprintf(stderr, "\n");
    fprintf(stderr, "Usage: <executable>\n");
    fprintf(stderr, "Usage: <executable> <output_path>\n");
    fprintf(stderr, "Usage: <executable> <output_path> <input_path>\n");
    return_code = BAD_NUM_ARGUMENTS;
    goto cleanup;
  }

  if (argc == 1) {
    in_file = stdin;
    out_file = stdout;
  }
  else if (argc == 2) {
    in_file = stdin;
    out_file = fopen(argv[1], "w");
    if (out_file == NULL) {
      fprintf(stderr, "Destination file cannot be written to (%s)", argv[1]);
      return_code = FILE_WRITE_ERR;
      goto cleanup;
    }
  }
  else {
    in_file = fopen(argv[2], "rb");
    if (in_file == NULL) {
      fprintf(stderr, "Input file cannot be opened (%s)", argv[2]);
    }
    if (in_file == NULL) {
      return_code = FILE_READ_ERR;
      goto cleanup;
    }

    out_file = fopen(argv[1], "w");
    if (out_file == NULL) {
      fprintf(stderr, "Destination file cannot be written to (%s)", argv[1]);
      return_code = FILE_WRITE_ERR;
      goto cleanup;
    }
  }

  /* Initialize message queue with capacity of 100 */
  if (message_queue_init(&queue, 100) != 0) {
    fprintf(stderr, "Failed to initialize message queue\n");
    return_code = -4;
    goto cleanup;
  }

  /* Read messages and buffer them in the queue */
  struct message message_data = {0};
  int message_code = read_message_from_file(in_file, &message_data);
  while (message_code == 0) {
    /* Enqueue the message */
    if (message_queue_enqueue(&queue, &message_data) != 0) {
      /* Queue is full, flush it before continuing */
      struct message buffered_msg = {0};
      while (message_queue_dequeue(&queue, &buffered_msg) == 0) {
        fprintf(out_file, "%ld,%u,%u,%u,%u,%u,%f,%f,%f,%f,",
                buffered_msg.time_stamp, buffered_msg.battery_temp,
                buffered_msg.SOC, buffered_msg.limit, buffered_msg.diag_one,
                buffered_msg.diag_two, buffered_msg.motor_curr,
                buffered_msg.motor_vel, buffered_msg.sink, buffered_msg.temp);
        print_bool_flags(out_file, &buffered_msg.oh_no_bits, ",");
        fprintf(out_file, ",%u\n", buffered_msg.oh_no_bits.aux_condition);
      }
      /* Retry enqueue after flushing */
      if (message_queue_enqueue(&queue, &message_data) != 0) {
        fprintf(stderr, "Failed to enqueue message\n");
        return_code = -4;
        goto cleanup;
      }
    }

    message_code = read_message_from_file(in_file, &message_data);
  }

  /* Flush remaining messages from queue */
  struct message buffered_msg = {0};
  while (message_queue_dequeue(&queue, &buffered_msg) == 0) {
    fprintf(out_file, "%ld,%u,%u,%u,%u,%u,%f,%f,%f,%f,",
            buffered_msg.time_stamp, buffered_msg.battery_temp,
            buffered_msg.SOC, buffered_msg.limit, buffered_msg.diag_one,
            buffered_msg.diag_two, buffered_msg.motor_curr,
            buffered_msg.motor_vel, buffered_msg.sink, buffered_msg.temp);
    print_bool_flags(out_file, &buffered_msg.oh_no_bits, ",");
    fprintf(out_file, ",%u\n", buffered_msg.oh_no_bits.aux_condition);
  }

cleanup:
  message_queue_destroy(&queue);

  if ((in_file != NULL) && (in_file != stdin)) {
    fclose(in_file);
    in_file = NULL;
  }
  if ((out_file != NULL) && (out_file != stdout)) {
    fclose(out_file);
    out_file = NULL;
  }
  return return_code;
} /* main() */
