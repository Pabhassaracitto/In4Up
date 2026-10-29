#!/bin/bash
cd wasm
emcmake cmake .
emmake make
cp ultratimestretch.js ../
cp ultratimestretch.wasm ../
echo "WASM build complete!"