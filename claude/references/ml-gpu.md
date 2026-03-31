# ML / GPU Reference

Machine-specific values. Update these for your hardware.

- **Shared HF cache**: `~/.cache/huggingface`. Never override `HF_HOME` per-project; all projects share the same downloaded models.
- **Model sizing**: 20GB VRAM fits ~7-8B models natively; ~32B quantized (IQ4_XS ~ 16-17 GB).
- **70W TDP**: this GPU is for inference and experimentation, not heavy training. Expect power throttling on sustained training workloads.
- **Docker GPU**: always use `--gpus all --shm-size=8g` (or `--ipc=host`) for PyTorch DataLoader with num_workers > 0.
- **gcc**: system gcc-11 is CUDA-compatible. Do not install or switch gcc versions.
- **CUDA_HOME**: `/usr/local/cuda`
