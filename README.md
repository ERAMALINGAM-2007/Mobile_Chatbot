# LocalRAG

LocalRAG is a Flutter app for creating focused chatbots backed by your own PDF and text documents. It stores documents, extracted text chunks, chatbots, and conversations locally, retrieves relevant passages for each question, and uses Google Gemini to generate grounded answers with document and page citations.

> **Not fully offline:** document storage and retrieval are local, but answer generation requires an internet connection and a Google Gemini API key. Relevant document excerpts and conversation context are sent to Gemini with each request.

## Features

- Create multiple chatbots, each with its own documents and conversations.
- Import PDF and TXT files; extract text and split it into searchable chunks.
- Retrieve relevant passages from the active chatbot’s knowledge base.
- Ask questions in a conversational chat and receive Markdown-formatted Gemini responses with source citations.
- Configure and test a Gemini API key and choose an available model in Settings.
- Keep app data in local SQLite storage and copied documents in app-private storage.

PDFs must contain selectable text. Scanned/image-only PDFs are not OCR-processed and may not produce usable content.

## Requirements

- Flutter SDK with Dart `^3.10.4` (see [`pubspec.yaml`](pubspec.yaml)).
- A configured Flutter development target and its platform toolchain.
- A Google Gemini API key for AI responses. Create or manage a key in [Google AI Studio](https://aistudio.google.com/apikey).

## Getting started

1. Clone the repository and open its root directory.
2. Install dependencies:

   ```sh
   flutter pub get
   ```

3. Start the app on a connected device or emulator:

   ```sh
   flutter run
   ```

4. Open **Settings**, enter your Gemini API key, select a model, and use the connection test to verify the configuration.
5. Create a chatbot, add PDF or TXT documents to its knowledge base, then open a conversation and ask a question.

The API key can be entered in the app; do not commit keys or other credentials to the repository.

## Run tests

Run the Flutter test suite from the repository root:

```sh
flutter test
```

## Project structure

| Path | Purpose |
| --- | --- |
| `lib/screens/` | Home, chatbot details, chat, and Gemini settings screens |
| `lib/services/documents/` | Document ingestion, text extraction, and chunking |
| `lib/services/rag/` | Local retrieval and prompt/context construction |
| `lib/services/llm/` | Gemini API integration and response streaming |
| `lib/repositories/` | Persistence operations for app data |
| `lib/core/database/` | SQLite database setup and schema |
| `test/` | Database, document processing, Gemini, and widget tests |

## Data and privacy

- Imported files are copied into app-private storage, and document metadata, chunks, chatbots, and conversations are stored locally.
- Questions are matched against the active chatbot’s local document chunks before generation.
- The retrieved excerpts, question, and conversation context are sent to Google Gemini to generate an answer. Review Google’s terms and data practices before uploading sensitive documents.
- The app persists the Gemini API key using `SharedPreferences`. Treat it as app-local configuration, not as a secure secrets vault; avoid using personal keys in redistributed builds.

## Troubleshooting

- **AI responses are unavailable:** check the API key in Settings, confirm internet access, and run the connection test.
- **A PDF has no usable text:** it may be scanned or image-only; use a text-based PDF or convert it to TXT with OCR first.
- **A document is not supported:** only `.pdf` and `.txt` files are accepted.
- **Flutter cannot find a device or build tools:** configure the target platform’s Flutter prerequisites, then check `flutter doctor`.
