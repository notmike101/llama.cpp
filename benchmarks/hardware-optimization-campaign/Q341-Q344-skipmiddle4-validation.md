# Q341-Q344 skip-middle4 validation

Fresh promoted controls B312-B314 produced an ordinary all-15 streamed generation median of 273.411962563219 tok/s. The qualification threshold was 293.411962563219 tok/s.

The opt-in `LLAMA_QWEN35_SKIP_MIDDLE4` graph mode skips decoder layers 20 through 23. Its target hot map contains the union of full-head top-20 traces from ordinary C++ generation, prose, Python, and long-context JSON workloads. The launcher also uses `p-split=0`.

Q341, Q342, and Q343 measured five-seed medians of 303.847856539490, 304.541114065536, and 295.895312050726 tok/s. The ordinary all-15 median was 302.486659093688 tok/s, a 29.074696530469 tok/s improvement over the fresh baseline.

All 15 C++ answers had stable per-seed hashes across the three batches, compiled with MSVC C++20 `/W4 /WX`, and passed their runtime assertions. The 1,080-token Python response was byte-identical to its full-head reference and passed Python syntax compilation. Prose was byte-identical to its full-head reference. The long-context response parsed as JSON with four risks, four mitigations, and six rollout steps.

Qualified binary hashes:

- `llama-server.exe`: `6F62F49915DE7EC58BE3E83E8C132BAA6B5CA5ED710151DA8D4CB02EC67C0566`
- `llama.dll`: `D77003B489D6B98EBA53E2BD8FDF8760E3C674B4BC03F028D3DDF6BE50F544DD`
- `llama-common.dll`: `AAF92917484B122A1C4A710F1F182A368CFC2A320FA91EBD27CBBC43A0D900CC`
- `ggml-cuda.dll`: `607B21407FFB6577CDD60FD6F1D1D32980971DCB57FC97018893664F6FC36319`
