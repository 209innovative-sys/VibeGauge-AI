import { useState } from "react";
import Landing from "./pages/Landing";
import Analyzer from "./Analyzer";

export default function App() {
  const [view, setView] = useState<"landing" | "app">("landing");

  return (
    <div className="min-h-screen transition-all duration-500 ease-out">
      {view === "landing" ? (
        <div className="animate-fadeIn">
          <Landing onTry={() => setView("app")} />
        </div>
      ) : (
        <div className="animate-scaleIn">
          <Analyzer />
        </div>
      )}
    </div>
  );
}
