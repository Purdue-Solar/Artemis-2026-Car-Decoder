/* can_decode.h */
#ifndef CAN_DECODE_H
#define CAN_DECODE_H

#include <stdint.h>

/*
 * Row 11 (2 bytes, MSB -> LSB):
 * Regen (1)
 * Cruise_Down (1)
 * Cruise_Up (1)
 * Cruise (1)
 * Aux Over Voltage (1)
 * Aux Under Voltage (1)
 * Aux Over Current (1)
 * Aux Current Warning (1)
 * Main Over Voltage (1)
 * Main Under Voltage (1)
 * Main Over Current Error (1)
 * Main Current Warning (1)
 * Aux Condition (4)
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

    uint8_t aux_condition; /* 0..15 */
} Row11Flags;

/* Decode from two bytes (msb = high byte, lsb = low byte) */
Row11Flags decode_row11_from_bytes(uint8_t msb, uint8_t lsb);

/* Print decoded Row 11 flags */
void print_row11(const Row11Flags *f);

#endif

static inline uint8_t bit_u16(uint16_t w, uint8_t pos) {
    return (uint8_t)((w >> pos) & 0x1u);
}

Row11Flags decode_row11_from_bytes(uint8_t msb, uint8_t lsb) {
    Row11Flags f;
    uint16_t w = ((uint16_t)msb << 8) | (uint16_t)lsb;

    f.regen                   = bit_u16(w, 15);
    f.cruise_down             = bit_u16(w, 14);
    f.cruise_up               = bit_u16(w, 13);
    f.cruise                  = bit_u16(w, 12);

    f.aux_over_voltage        = bit_u16(w, 11);
    f.aux_under_voltage       = bit_u16(w, 10);
    f.aux_over_current        = bit_u16(w,  9);
    f.aux_current_warning     = bit_u16(w,  8);

    f.main_over_voltage       = bit_u16(w,  7);
    f.main_under_voltage      = bit_u16(w,  6);
    f.main_over_current_error = bit_u16(w,  5);
    f.main_current_warning    = bit_u16(w,  4);

    f.aux_condition           = (uint8_t)(w & 0x0Fu); /* bits 3..0 */
    return f;
}

void print_row11(const Row11Flags *f) {
    if (!f) return;

    printf("Row11Flags {\n");
    printf("  regen=%u\n", f->regen);
    printf("  cruise_down=%u\n", f->cruise_down);
    printf("  cruise_up=%u\n", f->cruise_up);
    printf("  cruise=%u\n", f->cruise);

    printf("  aux_over_voltage=%u\n", f->aux_over_voltage);
    printf("  aux_under_voltage=%u\n", f->aux_under_voltage);
    printf("  aux_over_current=%u\n", f->aux_over_current);
    printf("  aux_current_warning=%u\n", f->aux_current_warning);

    printf("  main_over_voltage=%u\n", f->main_over_voltage);
    printf("  main_under_voltage=%u\n", f->main_under_voltage);
    printf("  main_over_current_error=%u\n", f->main_over_current_error);
    printf("  main_current_warning=%u\n", f->main_current_warning);

    printf("  aux_condition=%u\n", f->aux_condition);
    printf("}\n");
}