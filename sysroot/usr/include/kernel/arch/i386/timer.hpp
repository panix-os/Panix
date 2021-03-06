/**
 * @file timer.hpp
 * @author Keeton Feavel (keetonfeavel@cedarville.edu)
 * @brief
 * @version 0.3
 * @date 2019-11-15
 *
 * @copyright Copyright the Panix Contributors (c) 2019
 *
 */
#pragma once

#include <stdint.h>

#define TIMER_COMMAND_PORT 0x43
#define TIMER_DATA_PORT 0x40

extern volatile uint32_t px_timer_tick;

/**
 * @brief Initialize the CPU timer with the given frequency.
 *
 * @param freq Timer frequency
 */
void px_timer_init(uint32_t freq);
/**
 * @brief Prints out the current tick.
 *
 */
void px_timer_print();
/**
 * @brief Sleeps for a certain length of time.
 *
 * @param ms Sleep length in milliseconds
 */
void sleep(uint32_t ms);

void px_timer_register_callback(void (*func)());
