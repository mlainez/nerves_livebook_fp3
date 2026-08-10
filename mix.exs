defmodule NervesLivebookFP3.MixProject do
  use Mix.Project

  @app :nerves_livebook_fp3
  @version "0.1.0"
  @all_targets [:nerves_system_fp3]

  # Deterministic builds — same input, same firmware bytes.
  System.put_env("ERL_COMPILER_OPTIONS", "deterministic")

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.18",
      archives: [nerves_bootstrap: "~> 1.14"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  def application do
    [
      mod: {NervesLivebookFP3.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools,
        :inets,
        # Nerves runtime stack
        :nerves_pack,
        # FP3-specific userspace daemons
        :ex_rmtfs,
        :ex_tqftpserv,
        :ex_hexagonrpcd,
        :ex_hexagonfs,
        :ex_remoteproc,
        :ex_qcom_smgr,
        :ex_qbootctl,
        :ex_audio,
        :fp3_camera,
        :vintage_net_qmi,
        :fp3_modem,
        :ex_nfc,
        :ex_location,
        # The AI stack: this pulls arm_ai, nx_arm, infer_*, nerves_model_hub,
        # cpu_governor, nerves_data_resize via nerves_ai's mix.exs.
        :nerves_ai
      ]
    ]
  end

  defp deps do
    [
      # ---------------- Nerves runtime ----------------
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.4.0"},
      {:nerves_uevent, "~> 0.1.7", override: true},
      {:nerves_runtime, "~> 0.13.0"},
      {:nerves_pack, "~> 0.7"},
      {:nerves_time, "~> 0.4"},
      {:vintage_net, "~> 0.13"},
      {:vintage_net_ethernet, "~> 0.11"},

      # ---------------- Livebook ----------------
      {:livebook, "~> 0.19"},
      {:plug, "~> 1.16"},

      # ---------------- Kino integrations (used by the notebooks) ----------------
      {:kino, "~> 0.14"},
      {:kino_vega_lite, "~> 0.1.13"},
      {:kino_maplibre, "~> 0.1.0"},
      {:kino_bumblebee, "~> 0.5"},

      # ---------------- AI stack ----------------
      {:nerves_ai, path: "../nerves_ai"},

      # ---------------- FP3 hardware userspace ----------------
      {:ex_rmtfs, github: "mlainez/ex_rmtfs"},
      {:ex_tqftpserv, path: "../ex_tqftpserv"},
      {:ex_hexagonrpcd, path: "../ex_hexagonrpcd"},
      {:ex_hexagonfs, path: "../ex_hexagonfs"},
      {:ex_remoteproc, path: "../ex_remoteproc"},
      {:ex_qcom_smgr, path: "../ex_qcom_smgr"},
      {:ex_qbootctl, path: "../ex_qbootctl"},
      {:ex_audio, path: "../ex_audio"},
      {:fp3_camera, path: "../fp3_camera"},
      {:qmi, path: "../qmi", override: true},
      {:vintage_net_qmi, path: "../vintage_net_qmi"},
      {:fp3_modem, path: "../fp3_modem"},
      {:ex_nfc, path: "../ex_nfc"},
      {:ex_location, path: "../ex_location"},

      # ---------------- The nerves_system_fp3 (compiled here) ----------------
      {:nerves_system_fp3,
       path: "../nerves_system_fp3",
       runtime: false,
       targets: :nerves_system_fp3,
       nerves: [compile: true]}
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end
end
