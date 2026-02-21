#include <stdint.h>
#include <stdio.h>

struct status_flags {
  uint8_t regen;
  uint8_t cruise_down;
  uint8_t cruise_up;
  uint8_t cruise;
  uint8_t aux_over_voltage;
  uint8_t aux_under_voltage;
  uint8_t aux_over_current;
  uint8_t aux_current_warning;
  uint8_t main_over_voltage;
  uint8_t main_under_voltage;
  uint8_t main_over_current_error;
  uint8_t main_current_warning;
  uint8_t aux_condition;
};

void parse_status_flags(uint16_t bits, struct status_flags *flags);

int main(void) {
  struct status_flags flags;

  /* Test case 1: All bits set to 0 */
  parse_status_flags(0x0000, &flags);
  printf("Test 0x0000:\n");
  printf("  regen=%u, cruise=%u, aux_condition=%u\n\n", flags.regen,
         flags.cruise, flags.aux_condition);

  /* Test case 2: All bits set to 1 */
  parse_status_flags(0xFFFF, &flags);
  printf("Test 0xFFFF:\n");
  printf("  regen=%u, cruise_down=%u, cruise_up=%u, cruise=%u\n", flags.regen,
         flags.cruise_down, flags.cruise_up, flags.cruise);
  printf("  aux_over_voltage=%u, aux_under_voltage=%u\n",
         flags.aux_over_voltage, flags.aux_under_voltage);
  printf("  main_over_voltage=%u, main_under_voltage=%u\n",
         flags.main_over_voltage, flags.main_under_voltage);
  printf("  main_over_current_error=%u, main_current_warning=%u\n",
         flags.main_over_current_error, flags.main_current_warning);
  printf("  aux_condition=%u (should be 15)\n\n", flags.aux_condition);

  /* Test case 3: Only regen bit set */
  parse_status_flags(0x0001, &flags);
  printf("Test 0x0001 (regen only):\n");
  printf("  regen=%u, cruise=%u, main_over_voltage=%u\n\n", flags.regen,
         flags.cruise, flags.main_over_voltage);

  /* Test case 4: Aux condition = 0xA (1010 binary) */
  parse_status_flags(0xA000, &flags);
  printf("Test 0xA000 (aux_condition = 10):\n");
  printf("  aux_condition=%u, regen=%u\n\n", flags.aux_condition, flags.regen);

  /* Test case 5: Mixed flags */
  parse_status_flags(0x580F, &flags);
  printf("Test 0x580F:\n");
  printf("  regen=%u, cruise_down=%u, cruise_up=%u, cruise=%u\n", flags.regen,
         flags.cruise_down, flags.cruise_up, flags.cruise);
  printf("  main_over_current_error=%u, main_current_warning=%u\n",
         flags.main_over_current_error, flags.main_current_warning);
  printf("  aux_condition=%u (should be 5)\n", flags.aux_condition);

  return 0;
}
