#ifndef __UART_H_DEFINED__
#define __UART_H_DEFINED__

#include "log.h"

#define UART_LOG_LEVEL LOG_TRACE

void exit_with_status(int);
void require(const bool condition, const int exit_status);
int config_uart(int, char *argv[]);

typedef struct
{
	char *uart_fn;
	int speed;
	int data_bits;
	char parity;
	int stop_bits;
} uart_config_t;

enum
{
	PAR_UART_FN = 1,
	PAR_SPEED,
	PAR_DATA_BITS,
	PAR_PARITY,
	PAR_STOP_BITS,
	PAR_MAX
};

enum
{
	ERR_ARG_SPEED = 1,
	ERR_ARG_DATA_BITS,
	ERR_ARG_PARITY,
	ERR_ARG_STOP_BITS,
	ERR_CANT_OPEN_UART,
	ERR_USAGE,
	ERR_READ_STDIN_FAILED,
	ERR_READ_UART_FAILED
};

#endif
