#include <bsd/stdlib.h> // NOTE: sudo apt-get install libbsd-dev
#include <fcntl.h>
#include <strings.h>
#include <termios.h>

#include "uart.h"

#define BAUD_MIN 1200
#define BAUD_MAX 115200

static int
get_speed(int const speed)
{
  switch (speed) {
    case 1200: return B1200;
    case 1800: return B1800;
    case 2400: return B2400;
    case 4800: return B4800;
    case 9600: return B9600;
    case 19200: return B19200;
    case 38400: return B38400;
    case 57600: return B57600;
    case 115200: return B115200;
    default: exit_with_status(ERR_ARG_SPEED);
  }
}

static int
get_data_bits(int const data_bits)
{
  switch (data_bits) {
    case 5: return CS5;
    case 6: return CS6;
    case 7: return CS7;
    case 8: return CS8;
    default: exit_with_status(ERR_ARG_DATA_BITS);
  }
}

static void
set_options(struct termios* const options, uart_config_t const* const config)
{
  options->c_cflag = CLOCAL | CREAD;

  cfsetispeed(options, config->speed);
  cfsetospeed(options, config->speed);

  options->c_cflag |= config->data_bits;

  if (config->stop_bits == 2)
    options->c_cflag |= CSTOPB;

  switch (config->parity) {
    case 'N': break;
    case 'O':
      options->c_cflag |= PARENB;
      options->c_cflag |= PARODD;
      break;
    case 'E': options->c_cflag |= PARENB; break;
    default: exit_with_status(ERR_ARG_PARITY);
  }
}

static int
s2i(char const* const arg, int const min, int const max, int const err_code)
{
  const char* err;
  int         result = (int)strtonum(arg, min, max, &err);

  require(err == NULL, err_code);
  return result;
}

static void
parse_config(uart_config_t* const config, int const argc, char* const argv[])
{
  require(argc == PAR_MAX, ERR_USAGE);

  config->uart_fn   = argv[PAR_UART_FN];
  config->speed     = s2i(argv[PAR_SPEED], BAUD_MIN, BAUD_MAX, ERR_ARG_SPEED);
  config->data_bits = s2i(argv[PAR_DATA_BITS], 5, 8, ERR_ARG_DATA_BITS);
  config->parity    = argv[PAR_PARITY][0];
  config->stop_bits = s2i(argv[PAR_STOP_BITS], 1, 2, ERR_ARG_STOP_BITS);

  log_info("uart-config: %s, %d, %d-%c-%d",
           config->uart_fn,
           config->speed,
           config->data_bits,
           config->parity,
           config->stop_bits);

  config->speed     = get_speed(config->speed);
  config->data_bits = get_data_bits(config->data_bits);
}

int
config_uart(int argc, char* argv[])
{
  uart_config_t config = { 0 };

  parse_config(&config, argc, argv);

  int f_uart = open(config.uart_fn, O_RDWR | O_NOCTTY);
  require(f_uart > 0, ERR_CANT_OPEN_UART);
  tcflush(f_uart, TCIFLUSH);

  {
    struct termios options = { 0 };
    set_options(&options, &config);
    tcsetattr(f_uart, TCSANOW, &options);
  }

  return f_uart;
}
