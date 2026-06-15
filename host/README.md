# Host Tools / 上位机工具

`host/` contains tools that run on the development machine. They are not system/device source; they are allowed to be Python because the IR source rule applies to code that enters IRVibeOS itself.

## Recommended 1.0 Tool: hosted_vibe.py

`hosted_vibe.py` implements the hosted 1.0 workflow:

```text
intent -> LLVM IR -> verify with llvm-as -> save module -> optional lli run
```

Offline template mode:

```powershell
python host\hosted_vibe.py --name demo --intent "print a hello message" --provider template --run
```

OpenAI-compatible mode:

```powershell
python host\hosted_vibe.py `
  --name ai_demo `
  --intent "print three short lines about LLVM IR" `
  --provider openai-compatible `
  --api-base http://localhost:11434/v1 `
  --api-key dummy `
  --model llama3 `
  --run
```

Common options:

```text
--name <module>       module directory under modules/
--intent <text>       user intent
--provider <name>     template, openai, openai-compatible, or claude
--force               overwrite existing module
--run                 run with lli after saving
--print-ir            print generated IR
```

Environment variables:

```text
OPENAI_API_KEY
ANTHROPIC_API_KEY
IRVIBEOS_API_KEY
IRVIBEOS_API_BASE
IRVIBEOS_MODEL
```

## Experimental Tool: ai_host.py

`ai_host.py` speaks the TALK protocol to seeds and can call AI providers. It is useful for protocol experiments, but it is not the recommended 1.0 app-generation path.

Known limitation:

- It currently compiles LLVM IR to an object file and sends that object bytes to EXEC. A normal object file is not the same thing as a directly callable executable payload. The TALK EXEC payload format still needs to be designed and implemented.

Use this tool only when working on seed transport:

```powershell
python host\ai_host.py --port COM3 --baud 115200
python host\ai_host.py --stdio
```

Optional dependencies:

```powershell
pip install requests pyserial
```

`requests` is needed for AI calls. `pyserial` is needed for serial ports.
