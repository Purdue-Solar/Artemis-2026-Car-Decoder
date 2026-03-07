#include "decoder.h"

#include <stdio.h>

static struct status_flags
make_flags(unsigned regen, unsigned cruise_down, unsigned cruise_up,
           unsigned cruise, unsigned aux_over_voltage,
           unsigned aux_under_voltage, unsigned aux_over_current,
           unsigned aux_current_warning, unsigned main_over_voltage,
           unsigned main_under_voltage, unsigned main_over_current_error,
           unsigned main_current_warning) {
  struct status_flags flags = {0};
  flags.regen = regen;
  flags.cruise_down = cruise_down;
  flags.cruise_up = cruise_up;
  flags.cruise = cruise;
  flags.aux_over_voltage = aux_over_voltage;
  flags.aux_under_voltage = aux_under_voltage;
  flags.aux_over_current = aux_over_current;
  flags.aux_current_warning = aux_current_warning;
  flags.main_over_voltage = main_over_voltage;
  flags.main_under_voltage = main_under_voltage;
  flags.main_over_current_error = main_over_current_error;
  flags.main_current_warning = main_current_warning;
  return flags;
}

int main(void) {
  struct status_flags test1 = make_flags(1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0);
  struct status_flags test2 = make_flags(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  struct status_flags test3 = make_flags(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);
  struct status_flags test4 =
      make_flags(5, 0, 100, 0, 5, 0, 100, 0, 5, 0, 100, 0);
  struct status_flags test5 = make_flags(1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1);

  printf("Test 1 (comma): ");
  print_bool_flags(stdout, &test1, ",");
  printf("\n");

  printf("Test 2 (pipe): ");
  print_bool_flags(stdout, &test2, "|");
  printf("\n");

  printf("Test 3 (single): ");
  print_bool_flags(stdout, &test3, ",");
  printf("\n");

  printf("Test 4 (non-zero = true): ");
  print_bool_flags(stdout, &test4, " | ");
  printf("\n");

  printf("Test 5 (space delimiter): ");
  print_bool_flags(stdout, &test5, " ");
  printf("\n");

  return 0;
}
