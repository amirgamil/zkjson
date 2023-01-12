pragma circom 2.1.2;

include "circomlib/poseidon.circom";

template PoseidonLarge (inputSize) {
    signal input in[inputSize];
    signal output out;

    var numComponents = 1;
    if (inputSize > 16) {
        numComponents = 2 + ((inputSize - 17) \ 15);
    }

    component poseidons[numComponents];
    var counter = 0;
    var innerLoop;
    for (var i = 0; i < numComponents; i++) {
        if (i == numComponents - 1) {
            if (i == 0) {
                innerLoop = inputSize;
            } else {
                innerLoop = inputSize - counter + 1;
            }
        } else {
            innerLoop = 16;
        }
        poseidons[i] = Poseidon(innerLoop);
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