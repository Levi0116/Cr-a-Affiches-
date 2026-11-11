import { Composition } from "remotion";
import { Episode1 } from "./Episode1";
import { Lineup } from "./Lineup";
import { TOTAL } from "./timeline";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="Episode1" component={Episode1} durationInFrames={TOTAL} fps={30} width={1920} height={1080} />
    <Composition id="Lineup" component={Lineup} durationInFrames={1} fps={30} width={1920} height={1080} />
  </>
);
