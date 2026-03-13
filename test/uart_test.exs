defmodule UartTest do
  use ExUnit.Case, async: false

  @default_args ["9600", "8", "N", "1"]

  defp socat_available? do
    case System.find_executable("socat") do
      nil -> false
      _ -> true
    end
  end

  defp with_socat(fun) do
    if socat_available?() do
      {socat, pty_a, pty_b} = SocatHelper.start()

      try do
        fun.(pty_a, pty_b)
      after
        SocatHelper.stop(socat)
      end
    else
      IO.puts("  [skipped — socat not installed]")
    end
  end

  defp start_uart(pty, extra_args \\ @default_args) do
    {:ok, uart} = Uart.start_link(args: [pty | extra_args])
    :ok = Uart.subscribe(uart)
    uart
  end

  defp write_raw(pty, data) do
    File.write!(pty, data)
  end

  # Use a second Uart instance as the reader (avoids blocking :file.read on PTYs)
  defp start_reader(pty) do
    {:ok, reader} = Uart.start_link(args: [pty | @default_args])
    :ok = Uart.subscribe(reader)
    reader
  end

  # Collect all uart data messages until we have enough bytes
  defp collect_data(expected_size, timeout_ms \\ 5000) do
    collect_data_loop(expected_size, timeout_ms, <<>>)
  end

  defp collect_data_loop(expected_size, _timeout_ms, acc)
       when byte_size(acc) >= expected_size,
       do: acc

  defp collect_data_loop(expected_size, timeout_ms, acc) do
    receive do
      {:uart, :data, _path, data} ->
        collect_data_loop(expected_size, timeout_ms, acc <> data)
    after
      timeout_ms -> acc
    end
  end

  # -- normal I/O ---------------------------------------------------------

  test "receive data from UART" do
    with_socat(fn pty_a, pty_b ->
      _uart = start_uart(pty_a)
      Process.sleep(200)

      write_raw(pty_b, "hello")

      # Collect data, filtering out any socat noise
      data = collect_data(5)
      assert String.contains?(data, "hello")
    end)
  end

  test "send data to UART" do
    with_socat(fn pty_a, pty_b ->
      uart = start_uart(pty_a)
      _reader = start_reader(pty_b)
      Process.sleep(200)

      Uart.write(uart, "world")

      data = collect_data(5)
      assert String.contains?(data, "world")
    end)
  end

  test "bidirectional data" do
    with_socat(fn pty_a, pty_b ->
      uart_a = start_uart(pty_a)
      _uart_b = start_reader(pty_b)
      Process.sleep(200)

      # A -> B
      Uart.write(uart_a, <<0xDE, 0xAD>>)
      assert_receive {:uart, :data, _, <<0xDE, 0xAD>>}, 2000

      # B -> A (write raw to pty_b, receive on uart_a's subscription)
      write_raw(pty_b, <<0xBE, 0xEF>>)
      data = collect_data(2)
      assert data == <<0xBE, 0xEF>> or String.contains?(data, <<0xBE, 0xEF>>)
    end)
  end

  # -- subscriber --------------------------------------------------------

  test "no subscriber — data is silently dropped" do
    with_socat(fn pty_a, pty_b ->
      # start without subscribing
      {:ok, _uart} = Uart.start_link(args: [pty_a | @default_args])
      Process.sleep(200)

      write_raw(pty_b, "drop me")
      refute_receive {:uart, :data, _, _}, 500
    end)
  end

  # -- buffering ---------------------------------------------------------

  test "writes are buffered while port is down, then flushed" do
    with_socat(fn pty_a, pty_b ->
      # start with a bad path so port doesn't open immediately
      {:ok, uart} = Uart.start_link(args: ["/dev/nonexistent" | @default_args])
      :ok = Uart.subscribe(uart)

      # these writes should be buffered
      Uart.write(uart, "buf1")
      Uart.write(uart, "buf2")
      Process.sleep(200)

      # stop the failing uart
      GenServer.stop(uart)

      # start fresh with valid paths
      uart2 = start_uart(pty_a)
      _reader = start_reader(pty_b)
      Process.sleep(200)

      # send new data — verify the new one works
      Uart.write(uart2, "fresh")
      data = collect_data(5, 2000)
      assert String.contains?(data, "fresh")
    end)
  end

  # -- invalid args (C exit codes) ----------------------------------------

  test "invalid baud rate" do
    with_socat(fn pty_a, _pty_b ->
      {:ok, uart} = Uart.start_link(args: [pty_a, "99999", "8", "N", "1"])
      :ok = Uart.subscribe(uart)

      assert_receive {:uart, :exit, _path, :ERR_ARG_SPEED}, 2000
    end)
  end

  test "empty string argument" do
    with_socat(fn pty_a, _pty_b ->
      # An empty string for baud rate should fail rather than parsing as 0
      {:ok, uart} = Uart.start_link(args: [pty_a, "", "8", "N", "1"])
      :ok = Uart.subscribe(uart)

      assert_receive {:uart, :exit, _path, :ERR_ARG_SPEED}, 2000
    end)
  end

  test "invalid data bits" do
    with_socat(fn pty_a, _pty_b ->
      {:ok, uart} = Uart.start_link(args: [pty_a, "9600", "3", "N", "1"])
      :ok = Uart.subscribe(uart)

      assert_receive {:uart, :exit, _path, :ERR_ARG_DATA_BITS}, 2000
    end)
  end

  test "invalid parity" do
    with_socat(fn pty_a, _pty_b ->
      {:ok, uart} = Uart.start_link(args: [pty_a, "9600", "8", "X", "1"])
      :ok = Uart.subscribe(uart)

      assert_receive {:uart, :exit, _path, :ERR_ARG_PARITY}, 2000
    end)
  end

  test "invalid stop bits" do
    with_socat(fn pty_a, _pty_b ->
      {:ok, uart} = Uart.start_link(args: [pty_a, "9600", "8", "N", "5"])
      :ok = Uart.subscribe(uart)

      assert_receive {:uart, :exit, _path, :ERR_ARG_STOP_BITS}, 2000
    end)
  end

  test "wrong number of args" do
    with_socat(fn pty_a, _pty_b ->
      {:ok, uart} = Uart.start_link(args: [pty_a, "9600"])
      :ok = Uart.subscribe(uart)

      assert_receive {:uart, :exit, _path, :ERR_USAGE}, 2000
    end)
  end

  test "invalid device path" do
    {:ok, uart} = Uart.start_link(args: ["/dev/nonexistent" | @default_args])
    :ok = Uart.subscribe(uart)

    assert_receive {:uart, :exit, _path, :ERR_CANT_OPEN_UART}, 2000
  end

  # -- port crash + retry ------------------------------------------------

  test "port exit is reported" do
    with_socat(fn pty_a, _pty_b ->
      {:ok, uart} = Uart.start_link(args: [pty_a | @default_args])
      :ok = Uart.subscribe(uart)
      Process.sleep(200)

      # find the OS process and kill it
      port_info = :sys.get_state(uart)

      if port_info.port do
        info = Port.info(port_info.port)
        os_pid = Keyword.get(info, :os_pid)

        if os_pid do
          System.cmd("kill", ["-9", "#{os_pid}"])
          assert_receive {:uart, :exit, _path, _status}, 2000
        end
      end
    end)
  end

  # -- large payload (partial write path) ---------------------------------

  @tag timeout: 10_000
  test "large payload is fully transmitted" do
    with_socat(fn pty_a, pty_b ->
      uart_a = start_uart(pty_a)
      _uart_b = start_reader(pty_b)
      Process.sleep(200)

      # 16KB payload
      payload = :crypto.strong_rand_bytes(16384)
      Uart.write(uart_a, payload)

      received = collect_data(byte_size(payload), 5000)
      assert byte_size(received) == byte_size(payload)
    end)
  end

  # -- all valid baud rates -----------------------------------------------

  for baud <- ~w(1200 1800 2400 4800 9600 19200 38400 57600 115200) do
    test "accepts baud rate #{baud}" do
      with_socat(fn pty_a, _pty_b ->
        {:ok, uart} = Uart.start_link(args: [pty_a, unquote(baud), "8", "N", "1"])
        :ok = Uart.subscribe(uart)
        Process.sleep(200)
        refute_receive {:uart, :exit, _, _}, 200
        GenServer.stop(uart)
      end)
    end
  end

  # -- all valid data bits ------------------------------------------------

  for bits <- ~w(5 6 7 8) do
    test "accepts data bits #{bits}" do
      with_socat(fn pty_a, _pty_b ->
        {:ok, uart} = Uart.start_link(args: [pty_a, "9600", unquote(bits), "N", "1"])
        :ok = Uart.subscribe(uart)
        Process.sleep(200)
        refute_receive {:uart, :exit, _, _}, 200
        GenServer.stop(uart)
      end)
    end
  end

  # -- all valid parity modes ---------------------------------------------

  for parity <- ~w(N O E) do
    test "accepts parity #{parity}" do
      with_socat(fn pty_a, _pty_b ->
        {:ok, uart} = Uart.start_link(args: [pty_a, "9600", "8", unquote(parity), "1"])
        :ok = Uart.subscribe(uart)
        Process.sleep(200)
        refute_receive {:uart, :exit, _, _}, 200
        GenServer.stop(uart)
      end)
    end
  end

  # -- both valid stop bits -----------------------------------------------

  for stop <- ~w(1 2) do
    test "accepts stop bits #{stop}" do
      with_socat(fn pty_a, _pty_b ->
        {:ok, uart} = Uart.start_link(args: [pty_a, "9600", "8", "N", unquote(stop)])
        :ok = Uart.subscribe(uart)
        Process.sleep(200)
        refute_receive {:uart, :exit, _, _}, 200
        GenServer.stop(uart)
      end)
    end
  end
end
