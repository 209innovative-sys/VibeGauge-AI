export type Metric = {
  score: number | string;
  reason: string;
};

export type AnalysisResult = {
  honesty?: Metric;
  gaslighting?: Metric;
  hiddenAgenda?: Metric;
  miscommunication?: Metric;
  inLove?: Metric;
  flirting?: Metric;
  shy?: Metric;
  summary: string;

  // OCR text from screenshot (backend should return this)
  extractedText?: string;
};