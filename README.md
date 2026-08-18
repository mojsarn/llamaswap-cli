# llm-tools

The custom command suite for the mojs-AI inference server. None of this is
upstream software — it is plain bash and python written for this one machine,
which is exactly why it needs version control: the deployed copies live in
`/usr/local/bin` as root-owned files with no history.

**This repo is the source of truth.** Edit here, then `./install.sh`.

## Layout

    bin/llm                    main entry point (bash)
    bin/llm-plan               VRAM / offload planner (python)
    bin/llm-addmodel           writes a llama-swap config block (python)
    bin/llm-url                resolves model id or alias -> web UI URL (python)
    bin/gpu-stat               GPU utilisation snapshot for Intel Arc / xe (bash)
    bin/llama-server-sycl      wrapper, sources oneAPI setvars (bash)
    bin/llama-server-vulkan    wrapper for the Vulkan build (bash)
    install.sh                 deploy to /usr/local/bin

## Workflow

    ./install.sh --check   # is the deployed copy in sync with the repo?
    ./install.sh           # syntax-check, then deploy to /usr/local/bin
    ./install.sh --pull    # adopt live /usr/local/bin edits back into the repo

`install.sh` refuses to deploy if any script fails `bash -n` / `py_compile`,
because these land somewhere root executes them.

`--pull` exists because the deployed copies were edited directly for a long
time before this repo existed. If you (or a stray session) edit
`/usr/local/bin` by hand, pull the change back rather than losing it.

## What these depend on

These are **not** self-contained; they encode this machine's layout. Moving any
of it means editing these scripts:

| path | used by |
|---|---|
| `/etc/llama-swap/config.yaml` | `llm`, `llm-addmodel`, `llm-url` |
| `/opt/models/gguf/<org>/<repo>/` | `llm`, `llm-plan`, `llm-addmodel` |
| `/home/mojs/llama.cpp/gguf-py` | `llm info`, `llm-plan` (GGUF parsing) |
| `/opt/intel/oneapi/setvars.sh` | `llama-server-sycl` |
| `http://127.0.0.1:8080` | `llm` (llama-swap API) |

`llm` also shells out to `sudo` for `llm edit`, `llm reload`, and the config
write inside `llm get`.

## Gotchas worth knowing before editing

**Two different argument styles.** `llm info` / `llm plan` / `llm path` /
`llm rm` take a **`.gguf` filename** and resolve it via `find_model`.
`llm bench` / `llm ui` take a **model id or alias** (`org/repo:QUANT`, or an
alias from the config). Mixing them up is the most common confusion; the
filename form is a real file on disk, the id form is what the API answers to.

**`pgrep -af 'llama-server'` self-matches.** Any wrapper process whose argv
contains that string (a `bash -c` running one of these very commands, for
instance) shows up as a false hit. `llm list` and `llm vram` filter on field 2
ending in `/llama-server` to avoid it. Keep that filter if you touch them.

**`llama-swap` has semantic rules beyond valid YAML.** Duplicate aliases make
it refuse to start, and systemd will restart-loop quietly. After any config
change, run the duplicate-alias check in `../CLAUDE.md` and verify the service
actually came back — a dead service looks exactly like "every configuration
failed".

**`--parallel` needs `--kv-unified`.** llama.cpp enables the unified KV buffer
only when the slot count is *auto*. Passing `--parallel N` explicitly turns it
off, which hard-partitions context to `n_ctx / N` per slot. Always pass both.
Over-committing the shared pool fails **every** concurrent request at once
(HTTP 500), so `--parallel` is admission control, not just a throughput knob.
See `../MEASUREMENTS.md`.

## Related docs

- `../SETUP.md` — how the machine is built, and where everything lives
- `../TOOLS.md` — user-facing guide to these commands
- `../MEASUREMENTS.md` — everything actually benchmarked on this box
- `../CLAUDE.md` — operational rules and open threads
