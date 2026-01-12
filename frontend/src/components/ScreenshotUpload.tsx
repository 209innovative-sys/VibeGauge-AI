import React, { useEffect, useState } from "react";
import type { AnalysisResult } from "../types/analysis";

type ScreenshotUploadProps = {
  onResult: (result: AnalysisResult) => void;
  onError: (message: string) => void;
  canAnalyze: () => boolean;
};

const ScreenshotUpload: React.FC<ScreenshotUploadProps> = ({
  onResult,
  onError,
  canAnalyze,
}) => {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);

  const apiBase = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selected = e.target.files?.[0];
    if (!selected) return;

    if (!selected.type.startsWith("image/")) {
      const msg = "Please select a PNG or JPEG screenshot.";
      setLocalError(msg);
      onError(msg);
      setFile(null);
      setPreviewUrl(null);
      return;
    }

    setFile(selected);
    setLocalError(null);
    setPreviewUrl(URL.createObjectURL(selected));
  };

  const handleUpload = async () => {
    if (!file) {
      const msg = "Choose a screenshot first.";
      setLocalError(msg);
      onError(msg);
      return;
    }

    if (!canAnalyze()) return;

    setIsUploading(true);
    setLocalError(null);
    onError("");

    try {
      const formData = new FormData();
      formData.append("image", file);

      const res = await fetch(${apiBase}/analyze-image, {
        method: "POST",
        body: formData,
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || Screenshot analysis failed with );
      }

      const data = (await res.json()) as AnalysisResult;
      onResult(data);
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Unexpected screenshot analysis error.";
      setLocalError(message);
      onError(message);
      console.error(err);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div className="mt-4 space-y-2 rounded-2xl border border-slate-700 bg-slate-950/60 p-3">
      <div className="flex items-center justify-between gap-2">
        <span className="text-xs font-semibold text-slate-200">
          Or upload a screenshot
        </span>
        <button
          type="button"
          onClick={handleUpload}
          disabled={isUploading || !file}
          className="inline-flex items-center justify-center rounded-lg bg-fuchsia-500 px-3 py-1.5 text-[11px] font-semibold text-slate-950 shadow-md shadow-fuchsia-900/40 transition hover:bg-fuchsia-400 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isUploading ? "Analyzing..." : "Analyze Screenshot"}
        </button>
      </div>

      <label className="flex cursor-pointer flex-col items-center justify-center rounded-xl border border-dashed border-slate-600 bg-slate-900/60 px-3 py-4 text-center text-[11px] text-slate-400 hover:border-fuchsia-500/70 hover:text-fuchsia-300">
        <input
          type="file"
          accept="image/png,image/jpeg"
          className="hidden"
          onChange={handleFileChange}
        />
        <span className="font-medium">
          Click to choose a PNG or JPEG conversation screenshot
        </span>
        <span className="mt-1 text-[10px] text-slate-500">
          We only use it to analyze this compatibility. Nothing is stored.
        </span>
      </label>

      {previewUrl && (
        <div className="overflow-hidden rounded-xl border border-slate-700 bg-slate-900/70">
          <img
            src={previewUrl}
            alt="Conversation preview"
            className="max-h-64 w-full object-cover"
          />
        </div>
      )}

      {localError && (
        <p className="text-[11px] text-red-400">{localError}</p>
      )}
    </div>
  );
};

export default ScreenshotUpload;