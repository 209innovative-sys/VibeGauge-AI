import React from "react";

const BrandWatermark: React.FC = () => {
  return (
    <div className="pointer-events-none fixed inset-0 flex items-end justify-end px-4 py-3">
      <span className="select-none text-xs sm:text-sm font-semibold italic text-fuchsia-400/60 drop-shadow-[0_0_8px_rgba(236,72,153,0.8)]">
        Innovative Solutions
      </span>
    </div>
  );
};

export default BrandWatermark;
