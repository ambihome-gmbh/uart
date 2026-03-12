#include "uart.h"

#include <errno.h>
#include <stdlib.h>
#include <sys/select.h>
#include <unistd.h>

static int f_uart = -1;

void
exit_with_status(int const exit_status)
{
  log_error("exit(%d)", exit_status);
  if (f_uart >= 0) {
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

  ssize_t written = 0;
  while (written < size) {
    ssize_t const n = write(to, buf + written, size - written);
    if (n < 0) {
      if (errno == EINTR)
        continue;
      require(false, err_code + ERR_WRITE_ERROR_);
    }
    written += n;
  }
}

int
main(int argc, char* argv[])
{
  init_logger();

  f_uart = config_uart(argc, argv);

  int const maxfd = (f_uart > STDIN_FILENO ? f_uart : STDIN_FILENO) + 1;
  fd_set fds;

  for (;;) {
    FD_ZERO(&fds);
    FD_SET(f_uart, &fds);
    FD_SET(STDIN_FILENO, &fds);

    if (select(maxfd, &fds, NULL, NULL, NULL) < 0)
      continue;

    if (FD_ISSET(f_uart, &fds)) {
      forward(f_uart, STDOUT_FILENO, ERR_FWD_UART_FAILED_);
    }
    if (FD_ISSET(STDIN_FILENO, &fds)) {
      forward(STDIN_FILENO, f_uart, ERR_FWD_STDIN_FAILED_);
    }
  }

  return 0;
}
