pragma circom 2.1.0;

include "circomlib/comparators.circom";

template getCharType() {
  signal input in; // ascii value
  signal output out[9]; // 

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

  component equalsQuote = IsEqual();
  equalsQuote.in[0] <== in;
  equalsQuote.in[1] <== 34;
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

    signal states[jsonProgramSize+1][8];

    states[0][0] === 1;
    for (var i = 1; i < 8; i ++) {
      states[0][i] === 0;
    }
    
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

      charTypes[i].in <== jsonProgram[i];
      // charTypes[i].out is 1-hot encoding of type of character
      // states are } { , [ ] : 0-9 a-Z "

      // find new state
      states[i+1][1] <== states[i][0] * charTypes[i].out[1] + states[i][7] * charTypes[i].out[2] + states[i][3] * charTypes[i].out[1] + states[i][4] * charTypes[i].out[2];

      // Transition to 3
      states[i+1][2] <== states[i][5] * charTypes[i].out[8];

      // Transition to 4
      states[i+1][3] <== states[i][2] * charTypes[i].out[5];

      // Transition to 5
      states[i+1][4] <== states[i][6] * charTypes[i].out[8] + states[i][4] * charTypes[i].out[0] + states[i][7] * charTypes[i].out[0] + states[i][1] * charTypes[i].out[0];

      // Transition to 6
      states[i+1][5] <== states[i][1] * echarTypes[i].out[8] + states[i][5] * (1 - charTypes[i].out[8]);

      // Transition to 7
      states[i+1][6] <== states[i][3] * charTypes[i].out[8] + states[i][6] * (1 - charTypes[i].out[8]);

      // Transition to 8
      states[i+1][7] <== states[i][3] * charTypes[i].out[6] + states[i][7] * charTypes[i].out[6];


      for (var j = 0; j < stackDepth; j++) {
        gt[i][j] = LessThan(n);
        eq[i][j] = IsEqual(n);

        eq[i][j].in[0] <== j;
        eq[i][j].in[1] <== stackPtr[i];

        gt[i][j].in[0] <== j;
        gt[i][j].in[1] <== stackPtr[i];
        jsonStack[i + 1][j] <== jsonStack[i][j] * gt[i][j].out + eq[i][j].out * ;
      }
    }
}

component main { public [ bfProgram ] } = JsonFull(164, 5000);