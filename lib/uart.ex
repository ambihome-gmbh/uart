defmodule Uart do
  @moduledoc """
  Handles communication with a UART socket.

  Compiles and ships a small C program as an intermediate, which is communicated
  with as a `Port` from elixir.

  ## Example

      {:ok, uart} = Uart.start_link(args: ["/dev/pts/1", "9600", "8", "N", "1"])
      :ok = Uart.subscribe(uart)
      ...
      receive do
        {:uart, :data, _path, data} -> handle(data)
        {:uart, :exit, _path, exit_status} -> handle(exit_status)
      end
      ...
      Uart.write(uart, "Hello, world!")
      Uart.write(uart, << 0xDE, 0xAD, 0xBE, 0xEF >>)

  """

  use GenServer
  require Logger

  defstruct port: nil, subscriber: nil, args: []

  @exit_status [
                 :ERR_ARG_SPEED,
                 :ERR_ARG_DATA_BITS,
                 :ERR_ARG_PARITY,
                 :ERR_ARG_STOP_BITS,
                 :ERR_CANT_OPEN_UART,
                 :ERR_USAGE,
                 :ERR_FWD_STDIN_READ_FAILED,
                 :ERR_FWD_STDIN_WRITE_FAILED,
                 :ERR_FWD_UART_READ_FAILED,
                 :ERR_FWD_UART_WRITE_FAILED
               ]
               |> Enum.with_index(1)
               |> Map.new(fn {k, v} -> {v, k} end)

  def start_link(init_arg) do
    {opts, init_arg} = Keyword.split(init_arg, [:name])
    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  @spec write(GenServer.server(), binary()) :: :ok
  def write(server, data) do
    GenServer.cast(server, {:write, data})
  end

  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(server) do
    GenServer.call(server, :subscribe)
  end

  # -------------------------------------------------------------------

  @impl true
  def init(init_arg) do
    args = Keyword.fetch!(init_arg, :args)
    {:ok, %Uart{args: args}, {:continue, :start_uart}}
  end

  @impl true
  def handle_continue(:start_uart, state) do
    try do
      port =
        Port.open(
          {:spawn_executable, :code.priv_dir(:uart) ++ ~c"/c/uart"},
          [:exit_status, :binary, {:args, state.args}]
        )

      {:noreply, %{state | port: port}}
    rescue
      e ->
        Logger.warning(
          "failed to open UART on #{inspect(state.args, pretty: true)}: #{inspect(e)}"
        )

        {:stop, {:shutdown, :cant_open_port}, state}
    end
  end

  @impl true
  def handle_info({_port, {:data, data}}, state = %{subscriber: subscriber}) do
    Logger.debug("from port: data: #{inspect(data, base: :hex)}")

    if subscriber do
      send(subscriber, {:uart, :data, hd(state.args), data})
    end

    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, exit_status}}, state = %{subscriber: subscriber}) do
    Logger.info("from port: exit_status: #{@exit_status[exit_status]}")

    if subscriber do
      send(subscriber, {:uart, :exit, hd(state.args), @exit_status[exit_status]})
    end

    {:stop, {:shutdown, {:uart_closed, exit_status}}, state}
  end

  @impl true
  def handle_cast({:write, _data}, %{port: nil} = state) do
    {:noreply, state}
  end

  def handle_cast({:write, data}, %{port: port} = state) do
    Port.command(port, data)
    {:noreply, state}
  end

  @impl true
  def handle_call(:subscribe, {pid, _} = _from, state) do
    {:reply, :ok, %{state | subscriber: pid}}
  end
end
