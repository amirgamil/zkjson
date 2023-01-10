pragma circom 2.1.0;

include "circomlib/comparators.circom";

template getCharType() {
  signal input in; // ascii value
  signal output out[8]; // 

  component equals[6];
  for (var i = 0; i < 6; i ++) {
    equals[i] = IsEqual();
    if (i == 0) {
      equals[i].in[0] <== 125;
    }
    else if (i ==1) {
      equals[i].in[0] <== 123;
    }
    else if (i == 2) {
      equals[i].in[0] <== 44;
    }
    else if (i == 3) {
      equals[i].in[0] <== 91;
    }
    else if (i == 4) {
      equals[i].in[0] <== 93;
    }
    else if (i == 5) {
      equals[i].in[0] <== 58;
    }
    equals[i].in[1] <== in;
    out[i] <== equals[i].out;
  }
  component inRange[3];
  for (var i = 0; i < 3; i ++) {
    inRange[i] = InRange();
    inRange[i].in <== in;
  }
  if (i == 0) {
    inRange[i].left <== 48;
    inRange[i].right <== 57;
  }
  else if (i == 1) {
    inRange[i].left <== 97;
    inRange[i].right <== 122;
  }
  else {
    inRange[i].left <== 65;
    inRange[i].right <== 90;
  }
  out[6] <== inRange[0].out;
  out[7] <== inRange[1].out + inRange[2].out;
}

// @jsonProgramSize = large constant for max size json
template JsonFull(jsonProgramSize, stackDepth) {
    // string of all the json
    signal input jsonProgram[jsonProgramSize];
    // top of jsonStack always holds corresponding PC address
    // of the last corresponding bracket

    // + 1 to allocate empty memory field
    signal jsonStack[jsonProgramSize + 1][stackDepth];
    signal stackPtr[jsonProgramSize + 1];
    signal stackPtr[jsonProgramSize + 1];

    signal states[jsonProgramSize][8];
    
    // 
    component gt[jsonProgramSize][stackDepth];
    component eq[jsonProgramSize][stackDepth];

    component charTypes[jsonProgramSize];

    stackPtr[0] <== 0;

    for (var j = 0; j < stackDepth; j++) {
      jsonStack[0][j] <== 0;
    }

    jsonProgram[0] === 123;
    jsonProgram[jsonProgramSize-1] === 125;

    for (var i = 0; i < jsonProgramSize; i++) {
      charTypes[i] = getCharType();
      for (var j = 0; j < stackDepth; j++) {
        gt[i][j] = LessThan(n);
        eq[i][j] = IsEqual(n);

        eq[i][j].in[0] <== j;
        eq[i][j].in[1] <== stackPtr[i];

        gt[i][j].in[0] <== j;
        gt[i][j].in[1] <== stackPtr[i];
        jsonStack[i + 1][j] <== jsonStack[i][j] * gt[i][j].out + eq[i][j].out * ;
      }

      charTypes[i].in <== jsonProgram[i];
      charTypes[i].out // 1-hot encoding of type of character
    }

    // { = 123, } = 125, , = 44, [ = 91, ] = 93, : = 58, 0-9 = 48-57, a-z = 97-122, A-Z = 65-90

  
}

component main { public [ bfProgram ] } = BrainF(164, 5000);