defmodule SocatHelper do
  @moduledoc """
  Manages socat virtual serial port pairs for testing.

  Spawns `socat -d -d pty,raw,echo=0 pty,raw,echo=0` and parses
  the two PTY paths from its stderr output.
  """

  @doc """
  Starts a socat process linking two virtual serial ports.
  Returns `{port, pty_a, pty_b}`.
  """
  def start do
    port =
      Port.open(
        {:spawn, "socat -d -d pty,raw,echo=0 pty,raw,echo=0"},
        [:binary, :stderr_to_stdout, :exit_status]
      )

    {pty_a, pty_b} = read_pty_paths(port)
    # give socat a moment to fully set up
    Process.sleep(100)
    {port, pty_a, pty_b}
  end

  @doc """
  Stops a socat process.
  """
  def stop(port) do
    if info = Port.info(port) do
      if os_pid = Keyword.get(info, :os_pid) do
        System.cmd("kill", ["-9", to_string(os_pid)])
      end
    end

    Port.close(port)
  catch
    _, _ -> :ok
  end

  defp read_pty_paths(port) do
    read_pty_paths(port, [])
  end

  defp read_pty_paths(port, ptys) do
    receive do
      {^port, {:data, data}} ->
        new_ptys =
          Regex.scan(~r"PTY is (/dev/\S+)", data)
          |> Enum.map(fn [_, path] -> path end)

        ptys = ptys ++ new_ptys

        if length(ptys) >= 2 do
          [a, b | _] = ptys
          {a, b}
        else
          read_pty_paths(port, ptys)
        end

      {^port, {:exit_status, _}} ->
        raise "socat exited unexpectedly — is it installed?"
    after
      5000 ->
        raise "timed out waiting for socat PTY paths"
    end
  end
end
