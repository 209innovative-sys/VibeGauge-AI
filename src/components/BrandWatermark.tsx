import React from "react";

const BrandWatermark: React.FC = () => {
  return (
    <div
      className="fixed bottom-4 right-4 z-50 text-xs sm:text-sm md:text-base text-white/80 select-none pointer-events-none"
      style={{
        fontFamily: "'Pacifico','Brush Script MT',cursive",
        textShadow:
          "0 0 4px rgba(0,0,0,0.9), 0 0 14px rgba(255,255,255,0.6)",
      }}
    >
      <span className="px-4 py-2 rounded-full bg-black/60 backdrop-blur-md border border-white/20 shadow-lg shadow-black/60 tracking-wide">
        Innovative Solutions
      </span>
    </div>
  );
};

export default BrandWatermark;
