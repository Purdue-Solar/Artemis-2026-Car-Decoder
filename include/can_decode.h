/* can_decode.h */
#ifndef CAN_DECODE_H
#define CAN_DECODE_H

#include <stdint.h>
#include <stddef.h>
#include "buffer.h"

/*
  Row 11 (2 bytes, MSB->LSB):
  Regen (1)
  Cruise_Down (1)
  Cruise_Up (1)
  Cruise (1)
  Aux Over Voltage (1)
  Aux Under Voltage (1)
  Aux Over Current (1)
  Aux Current Warning (1)
  Main Over Voltage (1)
  Main Under Voltage (1)
  Main Over Current Error (1)
  Main Current Warning (1)
  Aux Condition (4)
*/
typedef struct {
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

    uint8_t aux_condition; // 0..15
} Row11Flags;

// Decode from two bytes (byte0 is MSB, byte1 is LSB)
Row11Flags decode_row11_from_bytes(uint8_t msb, uint8_t lsb);

// Convenience: read 2 bytes from Buffer and decode
int decode_row11_from_buffer(Buffer *buf, Row11Flags *out);

// Debug helper
void print_row11(const Row11Flags *f);

#endif
