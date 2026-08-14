# Qwen3.8-27B Q4_K_M

Run `run-qwen.bat` to serve the Q4_K_M model with its F16 vision projector.
The default 147,456-token context and Q8_0 K/V caches retain about 1 GiB of
free VRAM on the qualified RTX 3090 after a vision request.

The launcher defaults thinking to off. Anthropic clients enable it per request:

```json
{
  "thinking": {
    "type": "enabled",
    "budget_tokens": 1024
  }
}
```

Omitting `thinking`, or sending `{"thinking":{"type":"disabled"}}`, keeps
thinking disabled. The coding sampling defaults are temperature 0.6, top-k 20,
top-p 0.95, min-p 0.0, repeat penalty 1.0, and presence penalty 0.0.

The model and projector can be relocated with the `MODEL` and `MMPROJ`
environment variables. Other launcher defaults can be overridden the same way.
