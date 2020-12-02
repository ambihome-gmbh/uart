
# uart

minimal Elixir UART port.

## usage

```
{:ok, _} = Uart.start_link(['/dev/pts/3', '9600', '8', 'N', '1'])
:ok = Uart.subscribe()

receive do
	{:data, data} -> IO.inspect(data)
	{:exit, exit_status} -> IO.inspect(exit_status)
end
...
Uart.write("Hello, world!")
Uart.write(<< 0xDE, 0xAD, 0xBE, 0xEF >>)
```

## dev

### POSIX serial programming resources

- https://www.cmrr.umn.edu/~strupp/serial.html
- https://tldp.org/HOWTO/Serial-Programming-HOWTO/x115.html#AEN125
- https://tldp.org/HOWTO/Serial-HOWTO.html
- https://stackoverflow.com/questions/25996171/linux-blocking-vs-non-blocking-serial-read


### serial loopback

```
sudo apt install socat
sudo apt install minicom

socat -d -d pty,raw,echo=0 pty,raw,echo=0

sf@eternia:~/temp$ socat -d -d pty,raw,echo=0 pty,raw,echo=0
> 2020/11/24 19:38:59 socat[319915] N PTY is /dev/pts/4
> 2020/11/24 19:38:59 socat[319915] N PTY is /dev/pts/5
> 2020/11/24 19:38:59 socat[319915] N starting data transfer loop with FDs [5,5] and [7,7]

minicom -D /dev/pts/4
minicom -D /dev/pts/5
```

### write to stdin

https://serverfault.com/a/443303

```
mkfifo fifo
cat > fifo & 	# dummy process to keep the FIFO open 
fifo_cat_pid=$!
<program> < fifo

echo "Hello World" > fifo

// cleanup
kill $fifo_cat_pid
rm fifo
```

### GenServer

- https://hexdocs.pm/elixir/GenServer.html
- https://elixir-lang.org/cheatsheets/gen-server.pdf


###

- how to handle parity errors? parity needed?

