defmodule NervesLivebookFP3.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Make notebooks readable+writable on first boot. The rootfs is
    # read-only, but Livebook needs to save notebook state. We copy
    # the baked-in notebooks from /srv/livebook/notebooks/ to
    # /data/livebook/notebooks/ once; subsequent boots leave any
    # attendee edits intact. (/data is a symlink to /root, the
    # writable f2fs partition — see config.exs.)
    sync_notebooks()

    children =
      [
        # Children for all targets
      ] ++ target_children()

    opts = [strategy: :one_for_one, name: NervesLivebookFP3.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.target() == :host do
    defp target_children, do: []
  else
    defp target_children, do: []
  end

  defp sync_notebooks do
    source =
      Application.get_env(:nerves_livebook_fp3, :notebooks_source, "/srv/livebook/notebooks")

    dest = Application.get_env(:nerves_livebook_fp3, :notebooks_dest, "/data/livebook/notebooks")

    cond do
      not File.dir?(source) ->
        Logger.info("[workshop] no baked-in notebooks at #{source} — skipping sync")

      File.dir?(dest) and not Enum.empty?(File.ls!(dest)) ->
        Logger.info("[workshop] notebooks already present at #{dest} — preserving attendee edits")

      true ->
        File.mkdir_p!(dest)
        # Copy notebooks one by one so we don't overwrite an existing
        # one if someone partial-flashed.
        for name <- File.ls!(source) do
          src_path = Path.join(source, name)
          dst_path = Path.join(dest, name)
          if not File.exists?(dst_path), do: File.copy!(src_path, dst_path)
        end

        Logger.info("[workshop] copied #{length(File.ls!(source))} notebook(s) into #{dest}")
    end
  rescue
    e -> Logger.warning("[workshop] notebook sync failed: #{Exception.message(e)}")
  end
end
