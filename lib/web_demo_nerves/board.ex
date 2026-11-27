defmodule WebDemoNerves.Board do
  @moduledoc """
  The board's LEDs, buttons and sensors.

  The emulated machine has a virtio GPIO controller and a virtio I2C
  adapter (`gpio0` and `i2c0` in jsnerves' `nerves.cfg`). Linux makes them
  `/dev/gpiochip0` and `/dev/i2c-0`, and the page on the other side shows the
  LEDs, presses the buttons and answers for the sensors.

  GPIO lines, by name:

  * `LED_SLOT_A`, `LED_SLOT_B` - outputs, on for the firmware slot that runs
  * `LED_READY` - output, a heartbeat while the system is up (this
    application runs): two short beats, then a rest
  * `BUTTON_1`, `BUTTON_2`, `BUTTON_3` - inputs, 1 while pressed; presses
    are logged for now

  The power LED is not a GPIO: the page lights it while the machine runs.

  I2C sensors on `i2c-0`:

  * `0x10` - the frames per second the page renders: register 0 is an ID
    (`0x46`), registers 1-2 the rate in hundredths, big-endian. See `fps/0`.
  * `0x51` - a mailbox the page reads: the firmware writes what it runs there
    when it starts, and how an update goes. See `tell/2`.
  """
  use GenServer
  require Logger

  @slot_leds %{"a" => "LED_SLOT_A", "b" => "LED_SLOT_B"}
  @ready_led "LED_READY"
  # the heartbeat: on and off times in ms, repeated
  @heartbeat [{1, 110}, {0, 130}, {1, 110}, {0, 1150}]
  @buttons ["BUTTON_1", "BUTTON_2", "BUTTON_3"]

  @i2c_bus "i2c-0"
  @fps_address 0x10
  @fps_id 0x46
  @mailbox_address 0x51

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Read the FPS sensor: the frames per second the page renders
  """
  @spec fps() :: {:ok, float()} | {:error, term()}
  def fps() do
    with {:ok, bus} <- Circuits.I2C.open(@i2c_bus) do
      result = Circuits.I2C.write_read(bus, @fps_address, <<0>>, 3)
      Circuits.I2C.close(bus)

      case result do
        {:ok, <<@fps_id, centi::16>>} -> {:ok, centi / 100}
        {:ok, other} -> {:error, {:unexpected, other}}
        error -> error
      end
    end
  end

  @doc """
  Tell the page something: a line of text in one of the mailbox's registers

  Register 0 is what runs (`report/0`), register 1 how an update goes
  (`WebDemoNerves.Update`). Nobody listening is fine.
  """
  @spec tell(0..255, String.t()) :: :ok | {:error, term()}
  def tell(register, text) do
    with {:ok, bus} <- Circuits.I2C.open(@i2c_bus) do
      result = Circuits.I2C.write(bus, @mailbox_address, <<register, text::binary>>)
      Circuits.I2C.close(bus)
      result
    end
  end

  @doc """
  Tell the page which firmware slot runs, which version each slot holds and
  whether the running firmware is validated (fwup refuses to upgrade one that
  is not): `active=a a=1.2.2 b=1.2.3 valid=1`
  """
  @spec report() :: :ok | {:error, term()}
  def report() do
    kv = Nerves.Runtime.KV.get_all()

    tell(
      0,
      "active=#{kv["nerves_fw_active"]} a=#{kv["a.nerves_fw_version"]} b=#{kv["b.nerves_fw_version"]}" <>
        " valid=#{if Nerves.Runtime.firmware_valid?(), do: 1, else: 0}"
    )
  end

  @impl GenServer
  def init(_opts) do
    # So that terminate/2 turns the ready LED off when the system stops
    Process.flag(:trap_exit, true)

    active = Nerves.Runtime.KV.get("nerves_fw_active")

    leds =
      for {slot, name} <- @slot_leds, into: %{} do
        {name, output(name, if(slot == active, do: 1, else: 0))}
      end

    buttons = for name <- @buttons, gpio = input(name), do: gpio

    {:ok, %{leds: leds, ready: nil, buttons: buttons}, {:continue, :ready}}
  end

  @impl GenServer
  def handle_continue(:ready, state) do
    send(self(), :report)
    send(self(), {:heartbeat, 0})
    {:noreply, %{state | ready: output(@ready_led, 1)}}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, %{ref: name, value: value}}, state) do
    Logger.info("#{name} #{if value == 1, do: "pressed", else: "released"}")
    {:noreply, state}
  end

  # Say what runs, and again once it is validated: new firmware is validated
  # a little after it has started (the startup guard)
  def handle_info(:report, state) do
    _ = report()
    if not Nerves.Runtime.firmware_valid?(), do: Process.send_after(self(), :report, 1_000)
    {:noreply, state}
  end

  def handle_info({:heartbeat, step}, %{ready: ready} = state) do
    {level, ms} = Enum.at(@heartbeat, step)
    if ready, do: Circuits.GPIO.write(ready, level)
    Process.send_after(self(), {:heartbeat, rem(step + 1, length(@heartbeat))}, ms)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %{ready: ready}) do
    if ready, do: Circuits.GPIO.write(ready, 0)
  end

  defp output(name, value) do
    case Circuits.GPIO.open(name, :output, initial_value: value) do
      {:ok, gpio} ->
        gpio

      {:error, reason} ->
        Logger.warning("#{name}: #{inspect(reason)}")
        nil
    end
  end

  defp input(name) do
    with {:ok, gpio} <- Circuits.GPIO.open(name, :input),
         {:ok, _ref} <- Circuits.GPIO.subscribe(gpio, tag: name, trigger: :both) do
      gpio
    else
      {:error, reason} ->
        Logger.warning("#{name}: #{inspect(reason)}")
        nil
    end
  end
end
