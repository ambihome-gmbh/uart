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
  use TypedStruct

  require Logger

  typedstruct do
    field(:port, port() | nil)
    field(:subscriber, pid() | nil)
    field(:args, [], enforce: true)
    field(:buffer, [binary()], default: [])
  end

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
    {:ok, %Uart{args: args}, {:continue, :start_uart}}
  end

  @impl true
  def handle_continue(:start_uart, state) do
    state |> start_uart()
  end

  @impl true
  def handle_info(:start_uart, state) do
    state |> start_uart()
  end

  @impl true
  def handle_info({_port, {:data, data}}, state = %{subscriber: subscriber}) do
    Logger.debug("from port: data: #{inspect(data, base: :hex)}")

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
  def handle_cast({:write, data}, %{port: nil} = state) do
    {:noreply, state |> Map.update!(:buffer, &List.insert_at(&1, -1, data))}
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

  # privates
  defp start_uart(state) do
    args = state.args

    port =
      Port.open(
        {:spawn_executable, :code.priv_dir(:uart) ++ '/c/uart'},
        [:exit_status, :binary, {:args, args}]
      )

    if port != nil do
      state.buffer |> Enum.each(&Port.command(port, &1))

      {:noreply, %{state | port: port}}
    else
      Logger.warn("failed to open UART on\n#{inspect(args, pretty: true)}")

      Process.send_after(self(), :start_uart, 2000)

      {:noreply, state}
    end
  end
end
