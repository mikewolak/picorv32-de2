/*
 * Minimal Knight Rider Firmware
 * Clean implementation for RISC-V testing
 */

#include <stdint.h>

// Memory-mapped I/O addresses
#define LED_ADDR 0xFFFF0060

// LED patterns for Knight Rider effect
static const uint32_t knight_rider_patterns[] = {
    0x00001, 0x00002, 0x00004, 0x00008, 0x00010, 0x00020, 0x00040, 0x00080,
    0x00100, 0x00200, 0x00400, 0x00800, 0x01000, 0x02000, 0x04000, 0x08000,
    0x10000, 0x20000, 0x10000, 0x08000, 0x04000, 0x02000, 0x01000, 0x00800,
    0x00400, 0x00200, 0x00100, 0x00080, 0x00040, 0x00020, 0x00010, 0x00008,
    0x00004, 0x00002
};

// Simple delay function
void delay(uint32_t cycles) {
    for (volatile uint32_t i = 0; i < cycles; i++) {
        // Simple delay loop
    }
}

int main(void) {
    volatile uint32_t *led_reg = (volatile uint32_t *)LED_ADDR;
    uint32_t pattern_index = 0;
    const uint32_t num_patterns = sizeof(knight_rider_patterns) / sizeof(knight_rider_patterns[0]);

    // Main Knight Rider loop
    while (1) {
        // Set LED pattern
        *led_reg = knight_rider_patterns[pattern_index];

        // Delay
        delay(50000);

        // Next pattern (wrap around manually)
        pattern_index++;
        if (pattern_index >= num_patterns) {
            pattern_index = 0;
        }
    }

    return 0;
}