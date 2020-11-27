#include <unistd.h>
#include <stdlib.h>
#include "uart.h"

static fd_set fds;
static int f_uart = 0;
static char buf[BUFSIZ];
static FILE *f_log;

void exit_with_status(const int exit_status)
{
	log_error("exit(%d)", exit_status);
	if (f_uart)
	{
		close(f_uart);
	}
	if (f_log)
	{
		fclose(f_log);
	}
	exit(exit_status);
}

void require(const bool condition, const int exit_status)
{
	if (condition)
	{
		return;
	}
	exit_with_status(exit_status);
}

static void init_logger()
{
	log_set_quiet(true);
	f_log = fopen("log.txt", "a");
	log_add_fp(f_log, LOG_TRACE);
}

static void forward(const int from, const int to, const int offset, const int err_code)
{
	if (FD_ISSET(from, &fds))
	{
		size_t size = read(from, buf, BUFSIZ - 1);
		require(size > 0, err_code);
		write(to, buf, size);
	}
}

// todo warum kommt command zurueck?

int main(int argc, char *argv[])
{

	init_logger();

	f_uart = config_uart(argc, argv);
	int maxfd = f_uart + 1;

	for (;;)
	{
		FD_SET(f_uart, &fds);
		FD_SET(STDIN_FILENO, &fds);

		select(maxfd, &fds, NULL, NULL, NULL);

		forward(f_uart, STDOUT_FILENO, 0, ERR_READ_UART_FAILED);
		forward(STDIN_FILENO, f_uart, 1, ERR_READ_STDIN_FAILED);

		// usleep(5000);
	}

	return 0;
}

// 012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789