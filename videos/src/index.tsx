import React from 'react';
import {Composition, registerRoot, delayRender, continueRender} from 'remotion';
import '@fontsource/montserrat/500.css';
import '@fontsource/montserrat/600.css';
import '@fontsource/montserrat/700.css';
import '@fontsource/montserrat/800.css';
import '@fontsource/montserrat/900.css';
import '@fontsource/poppins/400.css';
import '@fontsource/poppins/500.css';
import '@fontsource/poppins/600.css';
import '@fontsource/poppins/600-italic.css';
import '@fontsource/poppins/700.css';
import '@fontsource/kaushan-script/400.css';
import {JBLVideo} from './Video';
import {FPS, TOTAL} from './data';
import {DJIVideo} from './DJIVideo';
import {D_FPS, D_TOTAL} from './dji-data';
import {HKVideo} from './HKVideo';
import {DJI2Video} from './dji2/Video2';
import {FPS2, TOTAL2} from './dji2/data';
import '@fontsource/orbitron/700.css';
import '@fontsource/orbitron/800.css';
import '@fontsource/orbitron/900.css';
import '@fontsource/rajdhani/600.css';
import '@fontsource/rajdhani/700.css';
import {H_FPS, H_TOTAL} from './hk-data';
import '@fontsource/unbounded/700.css';
import '@fontsource/unbounded/900.css';
import {AudioVideo} from './audio/AudioVideo';
import {FPS_A, TOTAL_A} from './audio/data';

const fontsHandle = delayRender('fonts');
Promise.all([
  '500 20px Montserrat', '700 20px Montserrat', '800 20px Montserrat', '900 20px Montserrat',
  '400 20px Poppins', '600 20px Poppins', 'italic 600 20px Poppins', '700 20px Poppins', '400 20px "Kaushan Script"', '700 20px Orbitron', '800 20px Orbitron', '900 20px Orbitron', '600 20px Rajdhani', '700 20px Rajdhani', '700 20px Unbounded', '900 20px Unbounded',
].map((f) => document.fonts.load(f))).then(() => continueRender(fontsHandle));

const Root: React.FC = () => (
  <>
    <Composition id="JBL" component={JBLVideo} durationInFrames={TOTAL} fps={FPS} width={1080} height={1920} />
    <Composition id="DJI" component={DJIVideo} durationInFrames={D_TOTAL} fps={D_FPS} width={1080} height={1920} />
    <Composition id="DJI3D" component={DJI2Video} durationInFrames={TOTAL2} fps={FPS2} width={1080} height={1920} />
    <Composition id="AUDIO" component={AudioVideo} durationInFrames={TOTAL_A} fps={FPS_A} width={1080} height={1920} />
    <Composition id="HK" component={HKVideo} durationInFrames={H_TOTAL} fps={H_FPS} width={1080} height={1920} />
  </>
);

registerRoot(Root);
