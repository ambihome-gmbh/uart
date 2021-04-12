#include "uart.h"

#include <stdlib.h>
#include <sys/select.h>
#include <unistd.h>

static int f_uart = -1;

void
exit_with_status(int const exit_status)
{
  log_error("exit(%d)", exit_status);
  if (f_uart) {
    close(f_uart);
  }
  exit(exit_status);
}

void
require(bool const condition, int const exit_status)
{
  if (condition) {
    return;
  } else {
    exit_with_status(exit_status);
  }
}

static void
init_logger()
{
  FILE* f_log = fopen("log.txt", "w");
  log_set_quiet(true);
  if (f_log != NULL) {
    log_add_fp(f_log, UART_LOG_LEVEL);
  }
}

static void
forward(int const from, int const to, int const err_code)
{
  static char   buf[BUFSIZ];
  ssize_t const size = read(from, buf, BUFSIZ);

  require(size > 0, err_code + ERR_READ_ERROR_);

  // TODO https://pubs.opengroup.org/onlinepubs/7908799/xsh/write.html
  // 	If write() is interrupted by a signal before it writes any data,
  // 	it will return -1 with errno set to [EINTR].
  ssize_t const write_size = write(to, buf, size);

  require(write_size == size, err_code + ERR_WRITE_ERROR_);
}

int
main(int argc, char* argv[])
{
  init_logger();

  f_uart = config_uart(argc, argv);

  int const maxfd = f_uart + 1;
  fd_set    fds;

  for (;;) {
    FD_ZERO(&fds);
    FD_SET(f_uart, &fds);
    FD_SET(STDIN_FILENO, &fds);

    select(maxfd, &fds, NULL, NULL, NULL);

    if (FD_ISSET(f_uart, &fds)) {
      forward(f_uart, STDOUT_FILENO, ERR_FWD_STDIN_FAILED_);
    }
    if (FD_ISSET(STDIN_FILENO, &fds)) {
      forward(STDIN_FILENO, f_uart, ERR_FWD_STDIN_FAILED_);
    }
  }

  return 0;
}
