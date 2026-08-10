defmodule NervesLivebookFP3 do
  @moduledoc """
  Workshop firmware for the FairPhone 3+, built on Nerves.

  Boots into a Livebook with pre-loaded notebooks for:

  * AI demos (chat / see / hear / speak / mix / Bumblebee)
  * Hardware discovery (sensors / camera / LEDs / vibration / GPS /
    modem / NFC / audio)

  Models are pre-baked into the firmware image at `/srv/models/`
  and copied to `/data/models/` on first boot (so they're writable
  if a notebook wants to re-export them). `/data` is the usual
  Nerves symlink to `/root`, the writable f2fs partition; `/srv`
  lives on the read-only rootfs.

  See the README and `/srv/livebook/notebooks/` for the workshop
  curriculum.
  """
end
