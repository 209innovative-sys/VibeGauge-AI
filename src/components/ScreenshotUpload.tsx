import React, { useState } from "react";

type ScreenshotUploadProps = {
  // Called with the JSON result from the backend
  onResult: (data: any) => void;
  // Optional: surface an error message to parent
  onError?: (message: string) => void;
};

const ScreenshotUpload: React.FC<ScreenshotUploadProps> = ({
  onResult,
  onError,
}) => {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const selected = event.target.files?.[0] ?? null;
    if (!selected) return;

    if (!["image/png", "image/jpeg"].includes(selected.type)) {
      const message = "Please upload a PNG or JPG screenshot.";
      setError(message);
      setFile(null);
      setPreviewUrl(null);
      onError?.(message);
      return;
    }

    if (selected.size > 10 * 1024 * 1024) {
      const message = "File is too large. Max size is 10 MB.";
      setError(message);
      setFile(null);
      setPreviewUrl(null);
      onError?.(message);
      return;
    }

    setError(null);
    setFile(selected);
    const url = URL.createObjectURL(selected);
    setPreviewUrl(url);
  };

  const handleAnalyze = async () => {
    if (!file) return;

    setIsLoading(true);
    setError(null);

    const apiBase =
      import.meta.env.VITE_API_BASE_URL ?? "http://localhost:5000";

    const formData = new FormData();
    formData.append("image", file);

    try {
      const response = await fetch(`${apiBase}/analyze-image`, {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const text = await response.text();
        const message =
          text || `Screenshot analysis failed with status ${response.status}.`;
        setError(message);
        onError?.(message);
        return;
      }

      const data = await response.json();
      onResult(data);
    } catch (err: unknown) {
      const message =
        err instanceof Error
          ? err.message
          : "Unexpected error while analyzing screenshot.";
      setError(message);
      onError?.(message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="mt-4 flex flex-col gap-3 rounded-2xl border border-slate-700 bg-slate-900/60 p-4">
      <div className="flex items-center justify-between gap-2">
        <h3 className="text-sm font-semibold text-slate-100">
          Screenshot analyzer
        </h3>
        {isLoading && (
          <span className="animate-pulse text-xs text-amber-400">
            Analyzing screenshot...
          </span>
        )}
      </div>

      <label className="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-slate-600 bg-slate-950/40 px-4 py-6 text-center transition hover:border-emerald-400 hover:bg-slate-900/70">
        <span className="text-xs text-slate-300">
          Drop a text-message screenshot here or click to browse
        </span>
        <span className="text-[10px] uppercase tracking-wide text-slate-500">
          PNG or JPG â€¢ up to 10 MB
        </span>
        <input
          type="file"
          accept="image/png,image/jpeg"
          className="hidden"
          onChange={handleFileChange}
        />
      </label>

      {previewUrl && (
        <div className="flex items-center gap-3">
          <img
            src={previewUrl}
            alt="Screenshot preview"
            className="h-20 w-auto rounded-lg border border-slate-700 object-cover"
          />
          <div className="flex flex-1 flex-col gap-2">
            <p className="truncate text-xs text-slate-300">
              {file?.name ?? "Selected screenshot"}
            </p>
            <button
              type="button"
              onClick={handleAnalyze}
              disabled={isLoading}
              className="inline-flex items-center justify-center rounded-lg border border-emerald-500/60 bg-emerald-500/80 px-3 py-1.5 text-xs font-medium text-slate-950 shadow-md shadow-emerald-900/40 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {isLoading ? "Analyzing..." : "Analyze Screenshot"}
            </button>
          </div>
        </div>
      )}

      {error && (
        <p className="text-xs text-red-400">
          {error}
        </p>
      )}

      {!previewUrl && (
        <p className="text-[11px] text-slate-400">
          Tip: Use this when you&apos;re too lazy to copy/paste the chat.
          Just upload a clear screenshot of the messages.
        </p>
      )}
    </div>
  );
};

export default ScreenshotUpload;
