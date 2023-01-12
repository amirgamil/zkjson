importScripts("./snarkjs.min.js");
self.addEventListener("message", async (evt) => {
    console.log("web worker recieved message");
    const [input, zkeyFile] = evt.data;
    const result = await snarkjs.groth16.fullProve(input, "/jsonFull.wasm", zkeyFile);
    postMessage(result);
});
