pragma circom 2.1.0;

include "circomlib/poseidon.circom";
include "circomlib/comparators.circom"

// @jsonProgramSize = large constant for max size json
template JsonFull(jsonProgramSize, stackDepth) {
    // string of all the json
    signal input jsonProgram[jsonProgramSize];
    // top of jsonStack always holds corresponding PC address
    // of the last corresponding bracket

    // + 1 to allocate empty memory field
    signal jsonStack[jsonProgramSize + 1][stackDepth];
    signal stackPtr[jsonProgramSize + 1];
    
    // 
    component gt[jsonProgramSize];

    stackPtr[0] <== 0;

    for (var j = 0; j < stackDepth; j++) {
      jsonStack[0][j] <== 0;
    }

    for (var i = 0; i < jsonProgramSize; i++) {

      for (var j = 0; j < stackDepth; j++) {
        gt = GreaterThan
        jsonStack[i + 1][j] <== jsonStack[i][j];
      }
    }
  
}

component main { public [ bfProgram ] } = BrainF(164, 5000);