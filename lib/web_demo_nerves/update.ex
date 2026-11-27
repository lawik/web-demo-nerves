defmodule WebDemoNerves.Update do
  @moduledoc """
  Firmware updates without a network: the page puts the update into a scratch
  area of the disk, and `install/0` applies it from there.

  The scratch area is the last 8 MB of `/dev/vda`, after the last partition
  (jsnerves' `extract_firmware.sh` adds it to the disk image). It starts with
  a header, `"NFWU"` and the size of the firmware file in bytes (32 bits,
  big-endian), and the `.fw` file follows. The file is an ordinary fwup
  archive, usually a delta against the firmware that runs.

  `install/0` hands it to fwup's `upgrade` task, which writes the slot that is
  not running, and reboots into it. The new firmware is validated once its
  applications have started (`startup_guard_enabled`); `revert/0` goes back
  to the slot that ran before.

  The page follows along through the board's mailbox
  (`WebDemoNerves.Board.tell/2`, register 1): `applying`, then `ok` or
  `failed`.
  """
  alias WebDemoNerves.Board

  @device "/dev/vda"
  @scratch_bytes 8 * 1024 * 1024
  @magic "NFWU"
  @file_path "/tmp/update.fw"

  @doc """
  Apply the update the page left in the scratch area and reboot into it
  """
  @spec install() :: :ok | {:error, term()}
  def install() do
    Board.tell(1, "applying")

    with {:ok, firmware} <- read(),
         :ok <- File.write(@file_path, firmware),
         :ok <- fwup() do
      File.rm(@file_path)
      Board.tell(1, "ok")
      IO.puts("Updated. Rebooting into the new firmware...")
      Nerves.Runtime.reboot()
    else
      {:error, reason} = error ->
        File.rm(@file_path)
        Board.tell(1, "failed")
        IO.puts("Update failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Go back to the firmware in the other slot, the one that ran before
  """
  @spec revert() :: :ok | {:error, term()}
  def revert() do
    IO.puts("Reverting to the previous firmware...")
    Nerves.Runtime.revert()
  end

  # The firmware file in the scratch area. The page wrote it under the
  # kernel, so what Linux has cached of that part of the disk is dropped
  # first.
  defp read() do
    _ = File.write("/proc/sys/vm/drop_caches", "1")

    with {:ok, sectors} <- File.read("/sys/block/vda/size"),
         start = String.to_integer(String.trim(sectors)) * 512 - @scratch_bytes,
         {:ok, device} <- :file.open(@device, [:read, :raw, :binary]) do
      result =
        case :file.pread(device, start, 8) do
          {:ok, <<@magic, size::32>>} when size > 0 and size <= @scratch_bytes - 8 ->
            :file.pread(device, start + 8, size)

          {:ok, _other} ->
            {:error, :no_update}

          other ->
            other
        end

      :file.close(device)
      result
    end
  end

  defp fwup() do
    args = ["-a", "-d", @device, "-t", "upgrade", "-i", @file_path]

    case System.cmd("fwup", args, stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_, 0} -> :ok
      {_, status} -> {:error, {:fwup, status}}
    end
  end
end
