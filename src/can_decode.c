/* can_decode.c */
#include "can_decode.h"
#include <stdio.h>

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

    f.aux_condition           = (uint8_t)(w & 0x0Fu); // bits 3..0
    return f;
}

int decode_row11_from_buffer(Buffer *buf, Row11Flags *out) {
    if (!buf || !out) return -1;

    uint8_t bytes[2];
    int rc = buffer_read(buf, bytes, 2);
    if (rc != 0) return -2;

    *out = decode_row11_from_bytes(bytes[0], bytes[1]);
    return 0;
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
