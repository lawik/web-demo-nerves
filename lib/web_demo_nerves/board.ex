defmodule WebDemoNerves.Board do
  @moduledoc """
  The board's LEDs, buttons and sensors.

  The emulated machine has a virtio GPIO controller and a virtio I2C
  adapter (`gpio0` and `i2c0` in jsnerves' `nerves.cfg`). Linux makes them
  `/dev/gpiochip0` and `/dev/i2c-0`, and the page on the other side shows the
  LEDs, presses the buttons and answers for the sensors.

  GPIO lines, by name:

  * `LED_SLOT_A`, `LED_SLOT_B` - outputs, on for the firmware slot that runs
  * `LED_READY` - output, on while the system is up (this application runs)
  * `BUTTON_1`, `BUTTON_2`, `BUTTON_3` - inputs, 1 while pressed; presses
    are logged for now

  The power LED is not a GPIO: the page lights it while the machine runs.

  I2C sensors on `i2c-0`:

  * `0x10` - the frames per second the page renders: register 0 is an ID
    (`0x46`), registers 1-2 the rate in hundredths, big-endian. See `fps/0`.
  """
  use GenServer
  require Logger

  @slot_leds %{"a" => "LED_SLOT_A", "b" => "LED_SLOT_B"}
  @ready_led "LED_READY"
  @buttons ["BUTTON_1", "BUTTON_2", "BUTTON_3"]

  @i2c_bus "i2c-0"
  @fps_address 0x10
  @fps_id 0x46

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
    {:noreply, %{state | ready: output(@ready_led, 1)}}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, %{ref: name, value: value}}, state) do
    Logger.info("#{name} #{if value == 1, do: "pressed", else: "released"}")
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
