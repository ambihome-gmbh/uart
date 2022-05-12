defmodule Uart do
  @moduledoc """
    {:ok, _} = Uart.start_link(['/dev/pts/1', '9600', '8', 'N', '1'])
    :ok = Uart.subscribe()
    ...
    receive do
      {:data, data} -> handle(data)
      {:exit, exit_status} -> handle(exit_status)
    end
    ...
    Uart.write("Hello, world!")
    Uart.write(<< 0xDE, 0xAD, 0xBE, 0xEF >>)
  """

  alias Toolbox, as: Tool
  use GenServer

  require Logger

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
               |> Tool.enum()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec write(binary()) :: :ok
  def write(data) do
    GenServer.cast(__MODULE__, {:write, data})
  end

  def subscribe() do
    GenServer.call(__MODULE__, :subscribe)
  end

  def subscribe(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  # -------------------------------------------------------------------

  @impl true
  def init(args) do
    state = %{
      port: nil,
      subscriber: nil,
      args: args
    }

    {:ok, state, {:continue, :start_uart}}
  end

  @impl true
  def handle_continue(:start_uart, state = %{args: args}) do
    port =
      Port.open(
        {:spawn_executable, :code.priv_dir(:uart) ++ '/c/uart'},
        [:exit_status, :binary, {:args, args}]
      )

    {:noreply, %{state | port: port}}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state = %{subscriber: subscriber}) do
    Logger.debug("from port: data: #{inspect data, base: :hex}")

    if subscriber do
      send(subscriber, {:data, data})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:exit_status, exit_status}}, state = %{subscriber: subscriber}) do
    Logger.info("from port: exit_status: #{@exit_status[exit_status]}")

    if subscriber do
      send(subscriber, {:exit, @exit_status[exit_status]})
    end

    {:noreply, %{state | port: nil}}
  end

  @impl true
  def handle_cast({:write, data}, %{port: port} = state) do
    Port.command(port, data)
    {:noreply, state}
  end

  @impl true
  def handle_call(:subscribe, {pid, _} = _from, state) do
    {:reply, :ok, %{state | subscriber: pid}}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscriber: pid}}
  end
end
