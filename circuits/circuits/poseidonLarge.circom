pragma circom 2.1.2;

include "circomlib/poseidon.circom";
// include "https://github.com/0xPARC/circom-secp256k1/blob/master/circuits/bigint.circom";

template PoseidonLarge (inputSize, numComponents) {
    signal input in[inputSize];
    signal output out;

    component poseidons[numComponents];
    var counter = 0;
    var innerLoop = 16;
    if (inputSize < 16) {
        innerLoop = inputSize;
    }
    for (var i = 0; i < numComponents; i++) {
        if (i == numComponents - 1) {
            poseidons[i] = Poseidon(inputSize - counter + 1);
            innerLoop = inputSize - counter + 1;
        } else {
            poseidons[i] = Poseidon(16);
        }
        
        if (i != 0) {
            poseidons[i].inputs[0] <== poseidons[i - 1].out;
            for (var j = 1; j < innerLoop; j++) {
                poseidons[i].inputs[j] <== in[counter];
                counter += 1;
            }
        } else {
            for (var j = 0; j < innerLoop; j++) {
                poseidons[i].inputs[j] <== in[counter];
                counter += 1;
            }
        }
    }
    out <== poseidons[numComponents - 1].out;
}