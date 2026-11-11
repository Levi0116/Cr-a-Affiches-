import { Composition } from "remotion";
import { Episode1 } from "./Episode1";
import { Lineup } from "./Lineup";
import { EpisodeV2, TOTAL_V2 } from "./EpisodeV2";
import { TOTAL } from "./timeline";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="Episode1" component={Episode1} durationInFrames={TOTAL} fps={30} width={1920} height={1080} />
    <Composition id="Episode1TikTok" component={Episode1} durationInFrames={TOTAL} fps={30} width={1080} height={1920} />
    <Composition id="Episode1TikTokV2" component={EpisodeV2} durationInFrames={TOTAL_V2} fps={30} width={1080} height={1920} />
    <Composition id="Episode1V2" component={EpisodeV2} durationInFrames={TOTAL_V2} fps={30} width={1920} height={1080} />
    <Composition id="Lineup" component={Lineup} durationInFrames={1} fps={30} width={1920} height={1080} />
  </>
);
