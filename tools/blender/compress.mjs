// Draco-compress the glBs Blender just wrote, when the result is smaller.
// Blender's apt build ships the exporter flag but not libextern_draco.so.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { NodeIO } from '@gltf-transform/core';
import { KHRDracoMeshCompression, KHRMaterialsEmissiveStrength } from '@gltf-transform/extensions';
import { draco } from '@gltf-transform/functions';
import draco3d from 'draco3dgltf';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const dir = path.join(root, 'public', 'models');

const io = new NodeIO()
  .registerExtensions([KHRDracoMeshCompression, KHRMaterialsEmissiveStrength])
  .registerDependencies({
    'draco3d.decoder': await draco3d.createDecoderModule(),
    'draco3d.encoder': await draco3d.createEncoderModule(),
  });

for (const name of fs.readdirSync(dir).filter((file) => file.endsWith('.glb'))) {
  const src = path.join(dir, name);
  const before = fs.statSync(src).size;
  const doc = await io.read(src);
  await doc.transform(draco({
    method: 'edgebreaker',
    encodeSpeed: 5,
    decodeSpeed: 5,
    quantizePosition: 14,
    quantizeNormal: 10,
  }));
  const tmp = path.join(dir, `.${name}.tmp.glb`);
  await io.write(tmp, doc);
  const after = fs.statSync(tmp).size;
  if (after < before) {
    fs.renameSync(tmp, src);
    console.log(`${name}: ${before} -> ${after}`);
  } else {
    fs.unlinkSync(tmp);
    console.log(`${name}: kept ${before} (draco was ${after})`);
  }
}
