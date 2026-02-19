CFLAGS = -g

HEADER_FILES = src

SRC =$(wildcard src/*.c)

OBJ = $(SRC:.c=.o)

DEFAULT_TARGETS ?= c_priv priv/c/uart

priv/c/uart: c_priv $(OBJ)
	$(CC) -I $(HEADER_FILES) -o $@ $(LDFLAGS) $(OBJ) $(LDLIBS) -lbsd -std=c99 -Wall -Wextra -Werror -pedantic

c_priv:
	mkdir -p priv/c

clean:
	rm -rf priv/c $(OBJ) $(BEAM_FILES)
