# Dev Notes 002: Verification and Testing Guide

This guide provides a structured approach to verify the implementation of **Dev Map 002: Stub Completion**. Use these steps to confirm that routing fixes, capability chips, and attachment stubs are production-ready.

## 1. Cloud Routing Verification

**Objective**: Ensure cloud models (especially Claude) correctly use the OpenRouter path and respect API key settings.

- [ ] **Claude Routing Test**:
    - Go to **Settings → Cloud API Keys**.
    - Ensure your **OpenRouter API Key** is entered.
    - Start a new chat.
    - Open the model picker and select **Claude Sonnet** or **Claude Opus**.
    - Send a message: "Who are you?"
    - **Expected**: The assistant should respond as a Claude model. Verify the "OpenRouter" identifier in the `StreamingService` logs if running in Xcode.
- [ ] **Missing Key Error Handling**:
    - Remove your OpenRouter API Key from Settings.
    - Attempt to send a message using any cloud model (Claude, GPT-4o, Gemini).
    - **Expected**: An assistant message should appear saying: "No API key configured for OpenRouter. Add your key in Settings → Cloud API Keys."

## 2. Capability Chips (System Prompt Augmentation)

**Objective**: Verify that the five bottom-row chips in the chat input bar correctly influence the AI's output.

- [ ] **Tone Test**:
    - Select **Tone: Professional**. Ask: "Tell me a joke."
    - **Expected**: A formal, dry, or professionally delivered joke.
    - Select **Tone: Creative**. Ask: "What is 2+2?"
    - **Expected**: An imaginative, metaphor-heavy explanation of basic arithmetic.
- [ ] **Length Test**:
    - Select **Length: Short**. Ask: "Summarise the history of the Internet."
    - **Expected**: A very brief response, ideally under 100 words.
    - Select **Length: Long**. Ask: "What is a cat?"
    - **Expected**: A detailed, multi-paragraph essay on felines.
- [ ] **Format Test**:
    - Select **Format: JSON**. Ask: "List three types of fruit."
    - **Expected**: A raw JSON object: `{"fruits": ["Apple", "Banana", "Cherry"]}`.
    - Select **Format: Plain Text**. Ask: "Write a bulleted list."
    - **Expected**: A list using plain characters (e.g., `-` or `*`) without any markdown bolding or headers.
- [ ] **Memory & Search**:
    - Toggle **Search** and ask about a recent 2024–2026 event.
    - **Expected**: The model should attempt to ground its answer in factual "search-style" data.
    - Toggle **Memory** and mention a preference (e.g., "I like cats"). Later in the chat, ask "What do I like?"
    - **Expected**: The model should recall the preference.

## 3. Attachments (Input Bar)

**Objective**: Confirm that URLs, Images, and Documents are ingested correctly.

- [ ] **Attach URL**:
    - Click **+ (Attach) → Attach URL**.
    - Enter a valid URL (e.g., `https://example.com`).
    - **Expected**: The text "Please read the following document..." followed by the stripped HTML content should appear in the text field.
- [ ] **Upload Image (Chat)**:
    - Click **+ (Attach) → Upload Image**.
    - Select any `.jpg` or `.png`.
    - **Expected**: A text reference like `[Image Attached: filename.jpg]` should be appended to the input text.
- [ ] **Truncation Logic**:
    - Paste a URL or attach a document with > 8,000 characters.
    - **Expected**: Ingestion should succeed, but the text should end with `[Document/URL content truncated to fit context window]`.

## 4. Sidebar & Article Verification

**Objective**: Confirm UI clarity and upgraded block functionality.

- [ ] **Sidebar UI**:
    - Check the **Apps** and **Library** sections in the sidebar.
    - **Expected**: Items like "Images", "Canvas", "Emails", and "Stories" should be greyed out with a small "Soon" label. They should no longer trigger toast messages.
- [ ] **Article Image Blocks**:
    - Go to **Library → Articles**.
    - Open an article or create a new one.
    - Add an **Image Block** (or find an existing placeholder).
    - Click the block (now a button labeled "Select Image").
    - Select an image file.
    - **Expected**: The image should render inside the block.
    - Relaunch the app and return to the article.
    - **Expected**: The image should persist across restarts (verify the absolute path is stored in the `ArticleBlock` model).

## 5. Automated Regression Suite

**Objective**: Run the new test files to ensure structural integrity.

- [ ] Run **`ServiceContainerTests`**: Verifies Claude routing logic.
- [ ] Run **`StreamingServiceTests`**: Verifies chip-driven prompt augmentation.
- [ ] Run **`DocumentIngestionServiceTests`**: Verifies truncation boundaries.

---
*Note: If `xcodebuild` is unavailable in your CLI environment, please run these tests directly from the Test Navigator (Cmd+U) in Xcode.*
