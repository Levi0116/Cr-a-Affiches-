import React from "react";
import { Composition, Folder } from "remotion";
import { Presentation } from "./Presentation";
import { Caisse } from "./scenes/Caisse";
import { Concept } from "./scenes/Concept";
import { Fonctionnalites } from "./scenes/Fonctionnalites";
import { Intro } from "./scenes/Intro";
import { Outro } from "./scenes/Outro";
import { Patron } from "./scenes/Patron";
import { Probleme } from "./scenes/Probleme";
import { Resultats } from "./scenes/Resultats";
import { Serveuse } from "./scenes/Serveuse";
import { Stock } from "./scenes/Stock";
import { DUREES, DUREE_TOTALE, FPS } from "./theme";

const commun = { fps: FPS, width: 1920, height: 1080 } as const;

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="Presentation" component={Presentation} durationInFrames={DUREE_TOTALE} {...commun} />
    <Folder name="Scenes">
      <Composition id="Intro" component={Intro} durationInFrames={DUREES.intro} {...commun} />
      <Composition id="Probleme" component={Probleme} durationInFrames={DUREES.probleme} {...commun} />
      <Composition id="Concept" component={Concept} durationInFrames={DUREES.concept} {...commun} />
      <Composition id="Serveuse" component={Serveuse} durationInFrames={DUREES.serveuse} {...commun} />
      <Composition id="Caisse" component={Caisse} durationInFrames={DUREES.caisse} {...commun} />
      <Composition id="Stock" component={Stock} durationInFrames={DUREES.stock} {...commun} />
      <Composition id="Patron" component={Patron} durationInFrames={DUREES.patron} {...commun} />
      <Composition id="Fonctionnalites" component={Fonctionnalites} durationInFrames={DUREES.fonctionnalites} {...commun} />
      <Composition id="Resultats" component={Resultats} durationInFrames={DUREES.resultats} {...commun} />
      <Composition id="Outro" component={Outro} durationInFrames={DUREES.outro} {...commun} />
    </Folder>
  </>
);
