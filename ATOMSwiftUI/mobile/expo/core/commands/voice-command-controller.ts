import { useMemo, useState } from "react";

type VoiceAdapterResult = {
  transcript: string;
  autoSubmit?: boolean;
};

type VoiceAdapter = {
  start: () => Promise<void>;
  stop: () => Promise<VoiceAdapterResult>;
};

class PlaceholderVoiceAdapter implements VoiceAdapter {
  async start() {
    return;
  }

  async stop() {
    return { transcript: "", autoSubmit: false };
  }
}

export function useVoiceCommandController() {
  const adapter = useMemo(() => new PlaceholderVoiceAdapter(), []);
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState("");

  const startListening = async () => {
    setIsListening(true);
    await adapter.start();
  };

  const stopListening = async () => {
    const out = await adapter.stop();
    setIsListening(false);
    if (out.transcript) setTranscript(out.transcript);
    return out;
  };

  const clearTranscript = () => setTranscript("");

  return {
    isListening,
    transcript,
    setTranscript,
    clearTranscript,
    startListening,
    stopListening,
  };
}
