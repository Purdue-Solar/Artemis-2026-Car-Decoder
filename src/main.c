/* main.c */
/* Authors: Daniel Xu */
#include <stdio.h>
#include <stdint.h>
#include "can_decode.h"

int main(void) {
    uint8_t incoming[2] = { 0xA5, 0x96 };

    Row11Flags flags = decode_row11_from_bytes(incoming[0], incoming[1]);

    print_row11(&flags);

    return 0;
}