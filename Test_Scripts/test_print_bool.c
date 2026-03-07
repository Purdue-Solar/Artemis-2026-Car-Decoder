#include <stdint.h>
#include <stdio.h>

void print_bool_array(FILE *file, const uint8_t *values, size_t length,
                      const char *delimiter);

int main(void) {
  uint8_t test1[] = {1, 0, 1, 0, 1};
  uint8_t test2[] = {0, 0, 0};
  uint8_t test3[] = {1};
  uint8_t test4[] = {5, 0, 100, 0};

  printf("Test 1 (comma): ");
  print_bool_array(stdout, test1, 5, ",");
  printf("\n");

  printf("Test 2 (pipe): ");
  print_bool_array(stdout, test2, 3, "|");
  printf("\n");

  printf("Test 3 (single): ");
  print_bool_array(stdout, test3, 1, ",");
  printf("\n");

  printf("Test 4 (non-zero = true): ");
  print_bool_array(stdout, test4, 4, " | ");
  printf("\n");

  printf("Test 5 (space delimiter): ");
  uint8_t test5[] = {1, 1, 0, 1};
  print_bool_array(stdout, test5, 4, " ");
  printf("\n");

  return 0;
}
