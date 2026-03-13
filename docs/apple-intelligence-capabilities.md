# Apple Intelligence App Capabilities, Constraints, and Developer Guidance

## Executive summary

Apple Intelligence is not a single "chatbot API" exposed to third-party developers. Instead, Apple's developer-facing surface area is a set of frameworks and system integrations that let apps (a) invoke on-device generative language capabilities via the Foundation Models framework, (b) invoke system image generation UI and programmatic image generation via Image Playground, (c) surface app content to system-level visual search via Visual Intelligence + App Intents, and (d) make actions and entities available to Siri and Shortcuts via App Intents (plus various "adjacent AI" APIs such as Vision, Speech, Translation, Natural Language, and Core ML for custom models).

For developers building an "accidental chatbot," the most important reality is that Apple's on-device Foundation Models framework is optimized for "everyday" app tasks (summarization, extraction, classification, short dialog, rewriting, etc.) and explicitly **is not designed to be a general world-knowledge chatbot**. You should expect hallucinations, refusals from safety guardrails, and hard context limits, and you must architect for these constraints.

On privacy and security, Apple positions Apple Intelligence as on-device by default, with a separate Apple-operated cloud system ("Private Cloud Compute") for requests requiring larger models or more compute. Apple claims PCC is designed for stateless processing, enforceable guarantees, no privileged runtime access, and verifiable transparency (including publishing production PCC builds for inspection and enabling independent verification via a Virtual Research Environment).

From a compliance and App Store standpoint, running a chatbot-like experience triggers two high-risk policy zones: (a) **user-generated content moderation** requirements (filtering, reporting, blocking, contact info) and (b) **data sharing disclosures and explicit permission**—including an explicit requirement to disclose and obtain permission before sharing personal data with **third-party AI**.

---

## Platform surface area and technical capabilities

### Comparison of major capability layers

| Dimension | On-device Foundation Models (developer API) | Private Cloud Compute (Apple-managed) | ChatGPT extension (Apple-managed integration) | Developer-managed cloud (your servers / third-party) |
|---|---|---|---|---|
| Primary entry points | Foundation Models framework (`SystemLanguageModel`, `LanguageModelSession`, guided generation, tool calling, streaming) | Used by Apple Intelligence for "advanced features" needing larger models; not a general third-party inference endpoint | Siri / Writing Tools / Visual Intelligence can hand off to ChatGPT when enabled; account optional; user controls confirmations | Any REST API you build/call; fully your responsibility; subject to App Store privacy rules and disclosures |
| Data leaves device | No (inference on-device), but you can still send data elsewhere if your app chooses | Yes, to Apple-operated PCC; Apple claims end-to-end encryption from device to validated PCC nodes and stateless deletion | Yes, to OpenAI **when invoked**; Apple obscures IP, provides coarse location; saving history requires signing in | Yes, by definition (unless purely local); must implement security, retention, and user rights flows |
| Context / "memory" | Session-based transcript, hard context window (4096 tokens/session); app must manage long-term memory itself | Apple does not publicly promise a developer-visible token window; used for "more sophisticated requests" needing larger models | ChatGPT has its own model/token behavior; Apple requires permissions controls; account enables chat history retention | You decide model/token window, storage, and retrieval; must disclose and secure |
| Tool / action integration | First-class tool calling in the Foundation Models framework (developer-defined Tool protocol) | Apple Intelligence internal orchestration; not a third-party tool-plugin platform as documented publicly | ChatGPT extension is controlled by system UI/permissions; not a general in-app plugin system | You can build agentic tools, but must mitigate prompt injection and excessive agency risks |
| Safety guardrails | Built-in guardrails; may refuse; limited "permissive transformations" mode exists, but guardrails remain | Apple claims PCC is built for privacy/security; output safety still applies via Apple Intelligence feature layers | OpenAI policies apply; Apple adds its own permission + privacy controls | You must implement moderation, filtering, and policy compliance; App Store UGC rules apply if users can generate/share content |

### On-device generative language via Foundation Models

The Foundation Models framework provides Swift-native access to an on-device language model that Apple describes as being "at the core" of Apple Intelligence, and Apple's machine learning research describes it as an approximately **3B-parameter on-device model** optimized for Apple silicon.

Key developer-controlled mechanisms:

**Sessioned interaction with instructions (system-like) and transcripts.** You create a `LanguageModelSession` and can supply persistent instructions for that session to shape persona, formatting, and safety boundaries at the app-feature level. Apple also documents session streaming methods for responsive UI.

**Real-time streaming.** The framework exposes streaming response APIs (returning streams of aggregated tokens), enabling partial UI updates or token-by-token experiences.

**Guided generation / typed output.** Apple's Foundation Models API supports guided generation that maps to Swift data structures (via the `@Generable` macro) and is designed to provide "strong guarantees" about type-conformant output. Apple explains this as a vertically integrated stack across compiler macros, prompt injection of output schemas, and OS-level constrained/speculative decoding.

**Tool calling / function calling.** Apple explicitly supports tool calling: you define tools and the model can decide to call them to fetch app-specific data or perform actions, with the framework managing tool-call graphs.

**Adapters for specialized skills.** Apple documents a Python toolkit for training rank-32 adapters for advanced, specialized use cases, and warns that adapters must be retrained per base model version.

### Image generation via Image Playground

Apple provides the Image Playground framework to present a system image generation interface (consistent UI) and also a programmatic API (`ImageCreator`) to generate images from prompts and styles.

- **System UI for safe image generation.** In SwiftUI, you can present an `imagePlaygroundSheet(...)` for user-driven generation, optionally seeded with concepts and a source image.
- **Programmatic generation.** Apple highlights programmatic generation via `ImageCreator` for more custom workflows, while still using system-managed generation.
- **ChatGPT-powered styles (system feature).** Apple states that Image Playground can "tap into ChatGPT" for new styles with user control and permission.

### Visual Intelligence integration via App Intents

Apple documents a Visual Intelligence framework that allows apps to integrate their own content into system visual search (camera or screenshot). The practical capability isn't "free vision inference" inside your app; it's **distribution and discoverability**: your catalog/content can appear as a result surfaced by the OS visual search UI, and users can deep-link into your app.

### Siri and Shortcuts integration via App Intents

Apple's App Intents framework is the main mechanism to expose app actions and entities to system experiences, including Siri, Shortcuts, Spotlight, and Apple Intelligence-enhanced action capabilities.

- **Tooling layer for user workflows.** Even if your app is not a "Siri app," App Intents lets you define deterministic actions that system intelligence can invoke.
- **A safer "agent" pattern.** App Intents can be used as a constrained action surface (a strongly typed set of allowed functions) instead of letting free-form model output directly trigger side effects—aligning with common LLM security guidance about minimizing "excessive agency."

### Adjacent on-device ML stack

- Vision framework for OCR/object detection
- Speech APIs (advanced speech-to-text sessions)
- Translation framework and Natural Language improvements
- Core ML for shipping custom models with compute-unit controls (CPU/GPU/Neural Engine)
- MLX as Apple's open-source framework for larger/custom LLM research on Apple silicon

---

## Operational constraints and limitations

### Availability constraints

Apple Intelligence requires: iPhone 15 Pro and later; iPad with M1 or later; Mac with M1 or later. Availability is a **runtime property** — the model can be unavailable because the device is ineligible, Apple Intelligence is not enabled, or the model is not ready (still downloading). Always check `SystemLanguageModel.default.availability`.

### Hard context window

Apple explicitly documents a **4096-token context window per language model session**. Without summarization, retrieval, or transcript pruning, multi-turn chat will hit limits quickly. Your app needs deterministic fallback behavior.

### Model capability boundaries

The ~3B on-device model excels at summarization, extraction, text understanding/refinement, short dialog, and creative content, but **is not designed to be a chatbot for general world knowledge**.

### Safety guardrails and refusal modes

The system has safety guardrails that can produce errors/refusals. A "permissive guardrail mode for sensitive content" (transformations) exists but does not frame as "turning off safety." Refusal frequency is not hypothetical — design refusal UX as a first-class path.

### Latency, performance, and battery

Apple provides `LanguageModelSession.prewarm(promptPrefix:)` to reduce latency for expected future prompts. Heavy inference can still impact energy use and thermals — profile and manage performance choices.

---

## Security, privacy, and compliance requirements

### On-device vs cloud processing

Apple's detailed PCC security architecture claims:
- **Stateless computation:** personal user data is used only to fulfill a request and is not retained
- **End-to-end encryption** from device to PCC nodes after cryptographic validation/attestation
- **No privileged runtime access:** no remote shell; restricted metrics/logging
- **Verifiable transparency:** publishing production PCC build artifacts into a transparency log

### App Store policy constraints

- Apps with UGC/social features must include filtering, reporting mechanisms, user blocking, and published contact information (Guideline 1.2)
- Apps used primarily for pornographic content, random/anonymous chat, threats, or bullying do not belong on the App Store
- You must disclose where personal data is shared with **third-party AI** and obtain explicit user permission before doing so (Guideline 5.1.2)
- Privacy manifests (`NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes`) required for declaring data types and API usage

### GDPR/CCPA

- Data minimization and purpose limitation (GDPR Art. 5)
- Security of processing expectations (GDPR Art. 32)
- Right to delete and consumer rights (CCPA)
- If storing chat transcripts server-side: deletion workflows, retention controls, breach response, accurate policy

---

## Best practices and mitigation strategies

### Adopt a "feature assistant" approach, not a general chatbot

1. Constrain the assistant to a narrow domain (app data and workflows)
2. Use tool calling for retrieval/verification
3. Output structured results via guided generation
4. Show citations/links inside your app UI when possible

### Guardrails-aware UX

- Detect guardrail errors and give a safe explanation + alternative paths
- Offer user controls that reduce accidental triggering
- Test edge cases with permissive transformations mode

### Manage context window limits

- **Sliding window transcript truncation** with deterministic retention rules (keep last N turns + pinned constraints)
- **Conversation summarization** (store a short state summary that replaces older turns)
- **Structured memory:** store extracted facts as typed records and re-inject only relevant ones

### Minimize "excessive agency" and prompt injection risk

- Implement a policy gate that validates tool arguments and enforces allowlists
- Require structured outputs and strict parsing before side effects
- Separate "instructions" from "untrusted content" — never concatenate external text into instructions

---

## Implementation patterns and code examples

### Suggested architecture

```
App UI → Policy Layer (redact, classify, budget tokens)
       → SystemLanguageModel availability check
       → [available] LanguageModelSession
                    → Tool calling (search DB, fetch docs, device state)
                    → Generate response
                    → [ok] Render stream + final
                    → [refusal] Refusal UX + alternatives
       → [unavailable] Fallback: deterministic UX / disable feature / server opt-in
```

### Availability check + basic response

```swift
import FoundationModels

func makeSessionIfAvailable() -> LanguageModelSession? {
    switch SystemLanguageModel.default.availability {
    case .available:
        return LanguageModelSession()
    case .unavailable:
        return nil
    @unknown default:
        return nil
    }
}

func respond(prompt: String) async throws -> String {
    guard let session = makeSessionIfAvailable() else {
        return "Apple Intelligence is unavailable on this device or not enabled."
    }
    let response = try await session.respond(to: prompt)
    return response.content
}
```

### Session instructions ("system prompt" pattern)

```swift
import FoundationModels

let session = LanguageModelSession(instructions: """
You are an assistant inside AcmeBudget.
- Only answer about the user's budget data visible to the app.
- If asked for facts outside the app, say you don't know and suggest using web search.
- Output in Markdown with short headings.
""")

let response = try await session.respond(to: "Summarize my spending last week.")
print(response.content)
```

### Streaming responses

```swift
import FoundationModels

let session = LanguageModelSession()
let stream = try await session.streamResponse(to: "Draft a short support reply apologizing for a delay.")
for try await chunk in stream {
    print(chunk)
}
```

### Typed / guided generation with `@Generable`

```swift
import FoundationModels

@Generable
struct SupportReply {
    var subject: String
    var body: String
    var followUpQuestion: String?
}

let session = LanguageModelSession()
let reply: SupportReply = try await session.respond(
    generating: SupportReply.self,
    prompt: "Write a concise support reply about resetting a password. Be polite."
)
```

### Tool calling pattern

```swift
import FoundationModels

struct LookupInvoiceTool: Tool {
    // Define name, input schema, and execution implementing the Tool protocol
}

let session = LanguageModelSession(tools: [LookupInvoiceTool()])
let response = try await session.respond(to: "What is the status of invoice #18421?")
print(response.content)
```

### Guardrails handling

```swift
import FoundationModels

do {
    let session = LanguageModelSession()
    _ = try await session.respond(to: userPrompt)
} catch {
    // Guardrails triggered — present safe UX:
    // - explain refusal
    // - ask user to revise
    // - offer non-AI alternative
}
```

### Image Playground: system UI

```swift
import SwiftUI

struct CoverArtView: View {
    @State private var showPlayground = false
    @State private var resultURL: URL?

    var body: some View {
        Button("Generate cover image") { showPlayground = true }
            .imagePlaygroundSheet(
                isPresented: $showPlayground,
                concepts: ["cozy", "mystery", "rainy street"],
                sourceImage: nil,
                onCompletion: { url in resultURL = url },
                onCancellation: { }
            )
    }
}
```

### Image Playground: programmatic generation

```swift
import ImagePlayground

let creator = ImageCreator()
let images = try await creator.generateImages(
    description: "A minimal icon of a compass in vector style",
    style: .vector,
    count: 2
)
```

### App Intents: expose actions to Siri/Shortcuts

```swift
import AppIntents

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"

    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "Category") var category: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
```

---

## Known gaps and workarounds

### Known gaps

- **No general chatbot parity by design** — the on-device model is not a world-knowledge assistant
- **4096-token context window** — hard architectural constraint forcing summarization/retrieval patterns
- **Refusals and sensitivity guardrails** — frequent; disabling safety is not a supported path
- **No public developer endpoint to PCC** — PCC is Apple-managed, not a callable general LLM API

### Practical workarounds

- **RAG-lite without embedding servers:** use tool calling + app search indices, return only top relevant snippets into the prompt
- **Use Core ML or MLX for specialized local models** when Foundation Models isn't a fit
- **Shift "assistant" behavior to deterministic App Intents** — expose a small set of actions, let the system do NL routing, keep side effects bounded

### Roadmap signals

- Continued improvements in tool-use, reasoning, and multimodal understanding at the model-family level
- Language expansion (Apple references models designed to support many languages)
- Apple's commitment to PCC transparency suggests continued evolution of cloud privacy mechanisms
- Increasing scrutiny and more prescriptive UX expectations for AI experiences per HIG updates
