
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

### usage with FTDI serial cable

plug in cable, then check `dmesg`

```
dmesg
[41733.619816] usb 1-8: FTDI USB Serial Device converter now attached to ttyUSB0
#																	     ^^^^^^^
```

the device is owned by `root` and group `dialout`. 

```
sf@grayskull:~$ ls -al /dev/ttyUSB0
crw-rw---- 1 root dialout 188, 0 Jul 10 14:14 /dev/ttyUSB0
#                 ^^^^^^^                          ^^^^^^^
```

so join the `dialout` group

```
sf@grayskull:~$ groups
sf adm cdrom sudo dip plugdev lpadmin lxd sambashare docker
sf@grayskull:~$ sudo usermod -a -G dialout $USER
```

this seems to have no effect

```
sf@grayskull:~$ groups
sf adm cdrom sudo dip plugdev lpadmin lxd sambashare docker
```

you have to login/logout or start a new shell

```
sf@grayskull:~$ su sf
sf@grayskull:~$ groups
sf adm dialout cdrom sudo dip plugdev lpadmin lxd sambashare docker
#      ^^^^^^^
```

(if still not in group, try a restart)

now you can connect with
```
{:ok, _} = Uart.start_link(['/dev/ttyUSB0', '19200', '8', 'N', '1'])
#                                 ^^^^^^^
```

some useful commands for troubleshooting:

```
dmesg
lsusb
find /sys/bus/usb/devices/usb*/ -name dev
udevadm info -a -p  $(udevadm info -q path -n /dev/ttyUSB0)
usb-devices
```

### example usage with knex-datalink

 (byte-stuffed) CEMI-frame
```
		11 AA 00 BC E0 FF FF AA 00 01 01 AA 00 80 00
ESC        ^^                ^^          ^^
END                                               ^^ 		
```

```
frame = <<0x11, 0xAA, 0x00, 0xBC, 0xE0, 0xFF, 0xFF, 0xAA, 0x00, 0x01, 0x01, 0xAA, 0x00, 0x80, 0x00>>
Uart.write(frame)
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

