import { AbsoluteFill } from "remotion";
import { Defs } from "./art/Defs";
import { Person } from "./art/Person";
import * as C from "./art/cast";

export const Lineup = () => (
  <AbsoluteFill style={{ background: "#3a4050" }}>
    <svg viewBox="0 0 1920 1080" width={1920} height={1080}>
      <Defs />
      {[C.YAO, C.BRAVO, C.BLESSE, C.GONMON1, C.GONMON2, C.KPOCLE1, C.KPOCLE2, C.CLIENT, C.JO, ...C.MICROBES].map((l, i) => (
        <Person key={i} look={l} x={100 + i * 145} y={1000} scale={i >= 9 ? 0.8 : 1} talk={i % 3 === 0 ? 0.6 : 0} expr={(["neutral", "smile", "panic", "angry", "focus", "angry", "smile", "worried", "neutral"] as const)[i % 9]} gaze={i % 2 ? 0.5 : -0.3} holdR={i === 1 ? "cigarette" : i === 0 ? "knife" : "none"} smoke={i === 1 ? 30 : 0} />
      ))}
      <Person look={C.YAO} x={300} y={500} scale={1} pose={{ sit: true, aR: [40, 60], aL: [30, 70], armsFront: true }} holdL="bread" holdR="knife" />
    </svg>
  </AbsoluteFill>
);
